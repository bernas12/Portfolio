#!/bin/bash

# Variables
LAMBDA_HANDLER="metric_app_V1.lambda_handler"
LAMBDA_ZIP_FILE="metric_app_V1.zip" # Make sure the .zip file is present
DYNAMO_TABLE_NAME="MetricsDB"
PARTITION_KEY="MetricID"
NAME_OF_RESOURCE='Metrics'
NAME_OF_STAGE="dev"

echo
echo "------------------------------------------------------------"
echo

echo(Metrics APP deployment started)

echo
echo "------------------------------------------------------------"
echo

# Create the Lambda role and attach policy
echo "Creating Lambda Role..."
read -p "Enter Lambda Role Name: " LAMBDA_ROLE_NAME
aws iam create-role --role-name "$LAMBDA_ROLE_NAME" --assume-role-policy-document file://lambda-policy.json # Make sure the lambda-policy.json file is present
sleep 5 # Wait for 5 seconds to give time for the role to be created
aws iam attach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
sleep 5
aws iam attach-role-policy --role-name "$LAMBDA_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

# Get the Lambda role ARN
LAMBDA_ROLE_ARN=$(aws iam get-role --role-name "$LAMBDA_ROLE_NAME" --query 'Role.Arn' --output text)
echo "Lambda Role ARN: '$LAMBDA_ROLE_ARN'"

echo
echo "------------------------------------------------------------"
echo

# Create the Lambda function
read -p "Enter Lambda Function Name: " LAMBDA_FUNCTION_NAME
echo "Creating Lambda Function..."
aws lambda create-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --runtime python3.12 \
    --role $LAMBDA_ROLE_ARN \
    --handler $LAMBDA_HANDLER \
    --zip-file fileb://$LAMBDA_ZIP_FILE

echo "Lambda Function '$LAMBDA_FUNCTION_NAME' created."

echo
echo "------------------------------------------------------------"
echo

# Create the DynamoDB table
echo "Creating DynamoDB table..."
aws dynamodb create-table \
    --table-name $DYNAMO_TABLE_NAME \
    --attribute-definitions AttributeName=$PARTITION_KEY,AttributeType=S \
    --key-schema AttributeName=$PARTITION_KEY,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

echo "Lambda Function '$DYNAMO_TABLE_NAME' created."

# Wait until the DynamoDB table becomes ACTIVE
echo "Waiting for DynamoDB Table '$DYNAMO_TABLE_NAME' to become ACTIVE..."
while true; do
    TABLE_STATUS=$(aws dynamodb describe-table \
        --table-name "$DYNAMO_TABLE_NAME" \
        --query "Table.TableStatus" \
        --output text)
    
    if [ "$TABLE_STATUS" == "ACTIVE" ]; then
        echo "DynamoDB Table '$DYNAMO_TABLE_NAME' is now ACTIVE."
        break
    else
        echo "DynamoDB Table status is '$TABLE_STATUS'. Waiting..."
        sleep 5  # Wait for 5 seconds before checking again
    fi
done

echo
echo "------------------------------------------------------------"
echo

# Create API Gateway
read -p "Enter APi Gateway Name: " API_NAME
read -p "Enter APi description (CANNOT be empty): " API_DESCRIPTION
read -p "Enter AWS Region: " AWS_REGION
echo "Creating API Gateway..."
aws apigateway create-rest-api \
    --name $API_NAME \
    --description "$API_DESCRIPTION" \
    --region $AWS_REGION

echo "API '$API_NAME' created."
echo

# Get API ID and Root resource ID
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='$API_NAME'].id" --output text)
ROOT_RESOURCE_ID=$(aws apigateway get-rest-apis --query "items[?name=='$API_NAME'].rootResourceId" --output text)
echo "API ID: '$API_ID'"
echo "Root resource ID: '$ROOT_RESOURCE_ID'"
echo

# Create Metrics resource for the API
echo "Creating Metrics Resource..."
aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part "$NAME_OF_RESOURCE" \
    --region $AWS_REGION

echo "Metrics Resource created."
echo

# Get Metrics Resource ID
NAME_OF_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/$NAME_OF_RESOURCE'].id" --output text)
echo "Metrics resource ID: '$NAME_OF_RESOURCE_ID'"
echo

# Create POST Method
echo "Creating POST Method..."
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $NAME_OF_RESOURCE_ID \
    --http-method POST \
    --authorization-type "NONE" \
    --region $AWS_REGION

echo "POST Method created."
echo

# Get Lambda Function ARN
LAMBDA_FUNCTION_ARN=$(aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --query 'Configuration.FunctionArn' --output text)
echo "Lambda Function ARN: '$LAMBDA_FUNCTION_ARN'"
echo

# Integrate API with Lambda Function
echo "Integrating API with Lambda Function..."
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $NAME_OF_RESOURCE_ID \
    --http-method POST \
    --type AWS \
    --integration-http-method POST \
    --uri arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$LAMBDA_FUNCTION_ARN/invocations \
    --region $AWS_REGION

echo "Integration completed."
echo

# Grante APi permition to invocate Lambda
echo "Granting API permition to invocate Lambda..."
read -p "Enter your AWS account ID: " AWS_ACCOUNT_ID
aws lambda add-permission \
    --function-name $LAMBDA_FUNCTION_NAME \
    --statement-id apigateway-post-permission \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn arn:aws:execute-api:$AWS_REGION:$AWS_ACCOUNT_ID:$API_ID/*/POST/$NAME_OF_RESOURCE

echo "Permitions granted."
echo

# Configure the method response for the POST Method
echo "Configuring Method response for POST..."
aws apigateway put-method-response \
    --rest-api-id $API_ID \
    --resource-id $NAME_OF_RESOURCE_ID \
    --http-method POST \
    --status-code 200 \
    --region $AWS_REGION

echo "Method response for POST method configured"
echo

# Configure integration response of the POST Method
echo "Configuring integration response for POST..."
aws apigateway put-integration-response \
    --rest-api-id $API_ID \
    --resource-id $NAME_OF_RESOURCE_ID \
    --http-method POST \
    --status-code 200 \
    --region $AWS_REGION

echo "Configuration completed."

echo
echo "------------------------------------------------------------"
echo

# Deploy the API
echo "Deploying the API"
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name $NAME_OF_STAGE \
    --region $AWS_REGION

echo "Invoke URL: https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/$NAME_OF_STAGE"
echo "API deployed"

echo
echo "------------------------------------------------------------"
echo

echo "Metrics APP deployment completed!"

echo
echo "------------------------------------------------------------"
echo