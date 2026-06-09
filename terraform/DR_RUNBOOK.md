# Clahan-Academy Disaster Recovery (DR) Runbook

This document describes the procedures for simulating a disaster, executing a failover to Southeast Asia, and failing back to Central India.

---

## DR Service Level Objectives (SLOs)

* **Recovery Point Objective (RPO):** `< 5 minutes` (data loss window limited by Azure PostgreSQL Flexible Server cross-region asynchronous replication lag).
* **Recovery Time Objective (RTO):** `< 15 minutes` (total time to detect outage, trigger automated alert/webhook, execute runbook to promote replica, and scale up container app instances).

---

## Disaster Simulation (Triggering Outage)

To test the disaster recovery pipeline, you can simulate an outage in the Primary (India) region:

### Option A: Disable the Primary Application Gateway Ingress
Delete the inbound security rules of the primary Application Gateway NSG to stop traffic:
```bash
az network nsg rule delete \
  --resource-group rg-clahan-<env>-india \
  --nsg-name nsg-clahan-india-appgw \
  --name AllowHTTPInbound
```

### Option B: Stop/Disable the Primary Container Apps
Scale the primary frontend-service to 0 replicas:
```bash
az containerapp update \
  --name ca-clahan-<env>-india-frontend-service \
  --resource-group rg-clahan-<env>-india \
  --min-replicas 0 --max-replicas 0
```

---

## Automated Failover (Alert Triggered)

1. **Detection:** Azure Front Door health probes GET `/` on `origin-india` fail.
2. **Alert Trigger:** The metric alert `alert-primary-down` evaluates `OriginHealthPercentage < 50%` for 2 minutes.
3. **Execution:** The alert triggers the Action Group `ag-clahan-dr`.
4. **Action:**
   * Sends alert email to the configured administrator email.
   * Triggers the Azure Automation webhook, executing runbook `rb-clahan-failover`.
5. **Runbook Actions:**
   * Promotes read-replica `pg-clahan-<env>-sea-replica` in Southeast Asia to primary.
   * Scales up all 11 Standby Container Apps in Southeast Asia (`min_replicas` updated from 0 to 1).
6. **Traffic Reroute:** Front Door automatically marks the India origin as unhealthy and reroutes 100% of incoming traffic to the Southeast Asia Application Gateway.

---

## Manual Failover (Admin Triggered)

If the automated alert is delayed and immediate action is required, the administrator can perform a manual failover:

### Method A: Execute via the manual failover script (Recommended)
Run the manual failover script provided in the `scripts` directory:
```bash
./scripts/failover-dr.sh <env>
```

### Method B: Execute via Azure Portal
1. Navigate to the Shared resource group: `rg-clahan-<env>-global`.
2. Open the Automation Account: `aa-clahan-<env>-global`.
3. Under **Process Automation**, click **Runbooks**.
4. Select `rb-clahan-failover`.
5. Click **Start** and monitor the output pane.

### Method C: Execute via Azure CLI
Run the promotion and scaling commands directly from your local terminal:
```bash
# 1. Promote the PostgreSQL Read Replica
az postgres flexible-server replica promote \
  --name pg-clahan-<env>-sea-replica \
  --resource-group rg-clahan-<env>-sea-dr \
  --yes

# 2. Scale up Standby Container Apps in SEA
APPS=("frontend-service" "auth-service" "admin-service" "student-service" "exam-service" "notification-service" "proctoring-service" "ai-service" "yolo-v8" "ocr" "ollama")
for app in "${APPS[@]}"; do
  az containerapp update \
    --name "ca-clahan-<env>-sea-$app" \
    --resource-group rg-clahan-<env>-sea-dr \
    --min-replicas 1
done
```

---

## Verification Steps

1. Check Front Door endpoint health:
   ```bash
   az network front-door backend-pool show \
     --resource-group rg-clahan-<env>-global \
     --front-door-name afd-clahan-<env>-global \
     --name og-clahan
   ```
2. Verify Southeast Asia Container Apps are running:
   ```bash
   az containerapp list \
     --resource-group rg-clahan-<env>-sea-dr \
     --query "[].{Name:name, ProvisioningState:properties.provisioningState}"
   ```
3. Confirm the SEA database is writable by checking its recovery status (should return `false`):
   ```sql
   SELECT pg_is_in_recovery();
   ```

---

## DR Failback Procedure (Returning to India)

Once the Central India region is restored, follow these steps to failback:

### 1. Synchronize Databases
Since the SEA database is now primary, data must be synchronized back to India.
1. Take a PG dump of the SEA database.
2. Restore the dump into the India PostgreSQL server.
3. Configure the India PostgreSQL server back as primary.
4. Re-create the replica relationship (SEA as replica, India as source).
   ```bash
   # Re-establish SEA as replica
   az postgres flexible-server replica create \
     --resource-group rg-clahan-<env>-sea-dr \
     --name pg-clahan-<env>-sea-replica \
     --source-server pg-clahan-<env>-india-main
   ```

### 2. Scale Down SEA Container Apps
Trigger the failback runbook to return SEA container apps to standby (0 compute resources):
```bash
# Start failback runbook
az automation runbook start \
  --name rb-clahan-failback \
  --resource-group rg-clahan-<env>-global \
  --automation-account-name aa-clahan-<env>-global
```

### 3. Restore India Ingress Rules (If disabled during test)
If you deleted the inbound NSG rules on the primary Application Gateway:
```bash
az network nsg rule create \
  --resource-group rg-clahan-<env>-india \
  --nsg-name nsg-clahan-india-appgw \
  --name AllowHTTPInbound \
  --access Allow \
  --protocol Tcp \
  --direction Inbound \
  --priority 100 \
  --source-address-prefix Internet \
  --source-port-range "*" \
  --destination-address-prefix "*" \
  --destination-port-ranges 80 443
```
Front Door health probes will detect that the India region is healthy, and traffic will automatically redirect back to Central India.
