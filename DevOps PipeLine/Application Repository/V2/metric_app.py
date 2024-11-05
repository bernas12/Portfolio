import json
import boto3
import uuid

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')

# Name of the DynamoDB table
TABLE_NAME = 'MetricsDB'

def lambda_handler(event, context):
    # Parse the incoming data from the event
       
        N_of_nodes = event['N_of_nodes']
        Market = event['Market']
        Country = event['Country']
        Customer = event['Customer']
        Activity = event['Activity']
        Product = event['Product']
        Site = event['Site']
        N_of_sites = event['N_of_sites']
        Upgrade_version = event['Upgrade_version']
        Remarks = event['Remarks']

        # Create a unique MetricID using UUID
        Metric_id = str(uuid.uuid4())

        # Construct item to insert into DynamoDB
        metrics_item = {
            'MetricID':Metric_id,
            'NofNodes': N_of_nodes,
            'Market': Market,
            'Country': Country,
            'Customer': Customer,
            'Activity': Activity,
            'Product': Product,
            'Site': Site,
            'NofSites': N_of_sites,
            'UpgradeVersion': Upgrade_version,
            'Remarks': Remarks
        }

        # Insert data into DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        
        # Save employer information
        table.put_item(Item=metrics_item)
        
        # Return success response
        return {
            'statusCode': 200,
            'body': json.dumps({'message': metrics_item})
        }