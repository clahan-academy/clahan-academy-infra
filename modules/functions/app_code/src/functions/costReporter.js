const { app } = require('@azure/functions');
const { DefaultAzureCredential } = require('@azure/identity');
const nodemailer = require('nodemailer');

// Core logic to query Azure API and send email
async function runCostReport(context) {
    context.log('Starting cost report execution...');

    const subscriptionId = process.env.AZURE_SUBSCRIPTION_ID;
    const resourceGroup = process.env.RESOURCE_GROUP;
    const smtpHost = process.env.SMTP_HOST || 'smtp.gmail.com';
    const smtpPort = process.env.SMTP_PORT || '587';
    const smtpUser = process.env.SMTP_USER;
    const smtpPass = process.env.SMTP_PASS;
    const smtpFrom = process.env.SMTP_FROM || smtpUser;
    const adminEmail = process.env.ADMIN_EMAIL;

    if (!subscriptionId || !resourceGroup) {
        throw new Error('Missing AZURE_SUBSCRIPTION_ID or RESOURCE_GROUP environment variables.');
    }

    if (!smtpUser || !smtpPass) {
        throw new Error('Missing SMTP_USER or SMTP_PASS environment variables.');
    }

    // Initialize Azure credentials
    const credential = new DefaultAzureCredential();
    const tokenResponse = await credential.getToken('https://management.azure.com/.default');
    const token = tokenResponse.token;

    // 1. Fetch Resource Inventory
    context.log('Fetching resource inventory...');
    const resourcesUrl = `https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/resources?api-version=2021-04-01`;
    const resInventory = await fetch(resourcesUrl, {
        headers: { 'Authorization': `Bearer ${token}` }
    });
    
    if (!resInventory.ok) {
        throw new Error(`Failed to fetch resource inventory: ${resInventory.statusText}`);
    }
    const inventoryData = await resInventory.json();
    const resources = inventoryData.value || [];
    context.log(`Found ${resources.length} resources in Resource Group ${resourceGroup}.`);

    // 2. Fetch Cost Query (Last 30 Days daily granularity)
    context.log('Querying cost management data...');
    const costUrl = `https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.CostManagement/query?api-version=2023-03-01`;
    
    // Get date range for cost query (last 30 days)
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(endDate.getDate() - 30);

    const queryBody = {
        type: 'ActualCost',
        timeframe: 'Custom',
        timePeriod: {
            from: startDate.toISOString().split('T')[0] + 'T00:00:00Z',
            to: endDate.toISOString().split('T')[0] + 'T23:59:59Z'
        },
        dataset: {
            granularity: 'Daily',
            aggregation: {
                totalCost: {
                    name: 'PreTaxCost',
                    function: 'Sum'
                }
            },
            grouping: [
                { type: 'Dimension', name: 'ResourceId' },
                { type: 'Dimension', name: 'ResourceType' }
            ]
        }
    };

    const resCost = await fetch(costUrl, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(queryBody)
    });

    if (!resCost.ok) {
        const errText = await resCost.text();
        context.error(`Cost API error: ${errText}`);
        throw new Error(`Failed to fetch cost data: ${resCost.statusText}`);
    }

    const costData = await resCost.json();
    const columns = costData.properties.columns;
    const rows = costData.properties.rows || [];

    // Helper to find index of columns
    const colIndex = (name) => columns.findIndex(c => c.name.toLowerCase() === name.toLowerCase());
    const costIdx = colIndex('PreTaxCost');
    const dateIdx = colIndex('UsageDate');
    const resourceIdIdx = colIndex('ResourceId');
    const resourceTypeIdx = colIndex('ResourceType');
    const currencyIdx = colIndex('Currency');

    // Parse yesterday's date string in YYYYMMDD format
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.toISOString().split('T')[0].replace(/-/g, '');

    let totalYesterdayCost = 0;
    let totalMonthCost = 0;
    let currency = 'USD';

    // Maps to aggregate costs
    const resourceCosts = {}; // resourceId -> { yesterdayCost: 0, monthCost: 0 }
    const typeCosts = {}; // resourceType -> { yesterdayCost: 0, monthCost: 0 }

    rows.forEach(row => {
        const cost = parseFloat(row[costIdx] || 0);
        const dateVal = String(row[dateIdx]);
        const resourceId = row[resourceIdIdx];
        const resourceType = row[resourceTypeIdx] ? row[resourceTypeIdx].toLowerCase() : 'other';
        const curr = row[currencyIdx] || 'USD';
        currency = curr;

        totalMonthCost += cost;

        if (!resourceCosts[resourceId]) {
            resourceCosts[resourceId] = { yesterdayCost: 0, monthCost: 0 };
        }
        resourceCosts[resourceId].monthCost += cost;

        if (!typeCosts[resourceType]) {
            typeCosts[resourceType] = { yesterdayCost: 0, monthCost: 0 };
        }
        typeCosts[resourceType].monthCost += cost;

        if (dateVal === yesterdayStr) {
            totalYesterdayCost += cost;
            resourceCosts[resourceId].yesterdayCost += cost;
            typeCosts[resourceType].yesterdayCost += cost;
        }
    });

    // Match inventory resources with cost data
    const inventoryReport = resources.map(r => {
        const costInfo = resourceCosts[r.id] || { yesterdayCost: 0, monthCost: 0 };
        return {
            name: r.name,
            type: r.type,
            location: r.location,
            yesterdayCost: costInfo.yesterdayCost.toFixed(2),
            monthCost: costInfo.monthCost.toFixed(2)
        };
    }).sort((a, b) => parseFloat(b.monthCost) - parseFloat(a.monthCost));

    // Format Type Costs for report
    const typeReport = Object.keys(typeCosts).map(type => ({
        type,
        yesterdayCost: typeCosts[type].yesterdayCost.toFixed(2),
        monthCost: typeCosts[type].monthCost.toFixed(2)
    })).sort((a, b) => parseFloat(b.monthCost) - parseFloat(a.monthCost));

    // 3. Compile HTML Email Report
    const htmlReport = `
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: 'Segoe UI', Arial, sans-serif; color: #333; margin: 0; padding: 20px; background-color: #f4f6f9; }
                .container { max-width: 800px; margin: 0 auto; background: #fff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); border-top: 5px solid #0078d4; }
                h1 { color: #0078d4; font-size: 24px; margin-bottom: 20px; }
                h2 { color: #555; font-size: 18px; border-bottom: 1px solid #ddd; padding-bottom: 8px; margin-top: 30px; }
                .summary-box { display: flex; gap: 20px; margin-bottom: 30px; }
                .card { flex: 1; padding: 15px; border-radius: 6px; background: #f0f4f8; border-left: 4px solid #0078d4; }
                .card-title { font-size: 12px; text-transform: uppercase; color: #666; font-weight: bold; }
                .card-value { font-size: 24px; font-weight: bold; color: #111; margin-top: 5px; }
                table { width: 100%; border-collapse: collapse; margin-top: 15px; }
                th { background-color: #f8fafc; color: #334155; font-weight: 600; text-align: left; padding: 10px; border-bottom: 2px solid #e2e8f0; font-size: 14px; }
                td { padding: 10px; border-bottom: 1px solid #e2e8f0; font-size: 13px; color: #475569; }
                tr:hover { background-color: #f8fafc; }
                .footer { margin-top: 40px; font-size: 12px; color: #999; text-align: center; border-top: 1px solid #eee; padding-top: 20px; }
                .badge { display: inline-block; padding: 3px 8px; font-size: 11px; font-weight: bold; border-radius: 12px; background: #e2e8f0; color: #475569; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Clahan Academy - Azure Cost & Resource Report</h1>
                <p>Report generated on <strong>${new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })} (IST)</strong></p>
                
                <div class="summary-box">
                    <div class="card">
                        <div class="card-title">Yesterday's Cost (${yesterday.toLocaleDateString()})</div>
                        <div class="card-value">${totalYesterdayCost.toFixed(4)} ${currency}</div>
                    </div>
                    <div class="card">
                        <div class="card-title">Month-To-Date Cost (Last 30 Days)</div>
                        <div class="card-value">${totalMonthCost.toFixed(4)} ${currency}</div>
                    </div>
                </div>

                <h2>Cost Breakdown by Resource Type</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Resource Type</th>
                            <th>Yesterday's Cost</th>
                            <th>Month-To-Date Cost</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${typeReport.map(tr => `
                            <tr>
                                <td><code>${tr.type}</code></td>
                                <td><strong>${tr.yesterdayCost} ${currency}</strong></td>
                                <td><strong>${tr.monthCost} ${currency}</strong></td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>

                <h2>Resource Inventory & Accrued Costs</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Resource Name</th>
                            <th>Type</th>
                            <th>Location</th>
                            <th>Yesterday's Cost</th>
                            <th>Month-To-Date</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${inventoryReport.map(r => `
                            <tr>
                                <td><strong>${r.name}</strong></td>
                                <td><span class="badge">${r.type.split('/').pop()}</span></td>
                                <td><code>${r.location}</code></td>
                                <td>${r.yesterdayCost} ${currency}</td>
                                <td>${r.monthCost} ${currency}</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>

                <div class="footer">
                    This is an automated report from the Clahan Academy Azure Cost Reporter function.
                </div>
            </div>
        </body>
        </html>
    `;

    // 4. Send Email via SMTP
    if (smtpHost && smtpUser && smtpPass && adminEmail) {
        context.log(`Sending cost report email to ${adminEmail}...`);
        
        const portVal = parseInt(smtpPort);
        const transporter = nodemailer.createTransport({
            host: smtpHost,
            port: portVal,
            secure: portVal === 465, // True for 465, false for 587
            auth: {
                user: smtpUser,
                pass: smtpPass
            }
        });

        const mailOptions = {
            from: `"Clahan Academy Billing" <${smtpFrom}>`,
            to: adminEmail,
            subject: `📊 Clahan Academy - Azure Cost & Resource Report (${new Date().toLocaleDateString()})`,
            html: htmlReport
        };

        const info = await transporter.sendMail(mailOptions);
        context.log(`Email sent successfully: ${info.messageId}`);
        return { success: true, message: `Report sent successfully to ${adminEmail}`, messageId: info.messageId };
    } else {
        context.log('SMTP settings are missing or incomplete. Email not sent.');
        return { success: false, message: 'SMTP settings missing. Print report to console only.', report: htmlReport };
    }
}

// Timer Trigger: Run at 8:00 AM IST daily (2:30 AM UTC)
app.timer('costReporterTimer', {
    schedule: '0 30 2 * * *', 
    handler: async (myTimer, context) => {
        try {
            await runCostReport(context);
        } catch (error) {
            context.error('Error running scheduled cost report:', error);
        }
    }
});

// HTTP Trigger: Allows testing/triggering manually via browser or curl
app.http('costReporterHttp', {
    methods: ['GET', 'POST'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        try {
            const result = await runCostReport(context);
            return {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(result)
            };
        } catch (error) {
            context.error('Error running manual cost report:', error);
            return {
                status: 500,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ success: false, error: error.message })
            };
        }
    }
});
