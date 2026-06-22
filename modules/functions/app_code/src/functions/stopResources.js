const { app } = require('@azure/functions');
const { DefaultAzureCredential } = require('@azure/identity');
const nodemailer = require('nodemailer');

app.timer('stopResources', {
    schedule: '0 30 23 * * *', // Run at 11:30 PM every day (local time based on WEBSITE_TIME_ZONE)
    handler: async (myTimer, context) => {
        context.log('Timer trigger function stopResources started execution.');
        
        try {
            const credential = new DefaultAzureCredential();
            const tokenResponse = await credential.getToken('https://management.azure.com/.default');
            const token = tokenResponse.token;

            const subscriptionId = process.env.AZURE_SUBSCRIPTION_ID;
            const resourceGroup = process.env.RESOURCE_GROUP;
            const aksName = process.env.AKS_CLUSTER_NAME;
            const vmName = process.env.VM_NAME || 'vm-clahan-jump';

            context.log(`Sub: ${subscriptionId}, RG: ${resourceGroup}, AKS: ${aksName}, VM: ${vmName}`);

            let aksStopped = false;
            let vmStopped = false;

            // Stop AKS Cluster
            if (subscriptionId && resourceGroup && aksName) {
                context.log(`Attempting to stop AKS cluster: ${aksName}`);
                const aksUrl = `https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.ContainerService/managedClusters/${aksName}/stop?api-version=2023-05-01`;
                const resAks = await fetch(aksUrl, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${token}`,
                        'Content-Type': 'application/json'
                    }
                });
                context.log(`AKS stop API call response status: ${resAks.status}`);
                aksStopped = (resAks.status === 200 || resAks.status === 202);
            }

            // Stop Jump VM
            if (subscriptionId && resourceGroup && vmName) {
                context.log(`Attempting to deallocate VM: ${vmName}`);
                const vmUrl = `https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Compute/virtualMachines/${vmName}/powerOff?api-version=2023-09-01`;
                const resVm = await fetch(vmUrl, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${token}`,
                        'Content-Type': 'application/json'
                    }
                });
                context.log(`VM stop API call response status: ${resVm.status}`);
                vmStopped = (resVm.status === 200 || resVm.status === 202);
            }

            // Send Alert Email
            const smtpHost = process.env.SMTP_HOST;
            const smtpPort = process.env.SMTP_PORT;
            const smtpUser = process.env.SMTP_USER;
            const smtpPass = process.env.SMTP_PASS;
            const adminEmail = process.env.ADMIN_EMAIL;

            if (smtpHost && smtpUser && smtpPass && adminEmail) {
                context.log(`Sending alert email to ${adminEmail}`);
                const transporter = nodemailer.createTransport({
                    host: smtpHost,
                    port: parseInt(smtpPort || '587'),
                    secure: false,
                    auth: {
                        user: smtpUser,
                        pass: smtpPass
                    }
                });

                await transporter.sendMail({
                    from: smtpUser,
                    to: adminEmail,
                    subject: '🔔 Alert: Clahan Academy Resources Scheduled Stop',
                    text: `Dear Administrator,\n\nThe scheduled resource stop function has executed at 11:30 PM IST.\n\n` +
                          `- AKS Cluster (${aksName}) Stop Request: ${aksStopped ? 'SUCCESS' : 'FAILED/SKIPPED'}\n` +
                          `- Jump VM (${vmName}) Stop Request: ${vmStopped ? 'SUCCESS' : 'FAILED/SKIPPED'}\n\n` +
                          `Best regards,\nClahan Academy DevOps`
                });
                context.log('Alert email sent successfully.');
            } else {
                context.log('SMTP configuration is missing. Alert email was not sent.');
            }

        } catch (error) {
            context.error('Error executing resource stop function:', error);
        }
    }
});
