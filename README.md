# ai-tools
Infrastructure for helping AI be accessible and useful with everyday tasks!

## Current tools
1. URL Summarizer - give it a URL and it will give you back the summary of the content of a web page.

## Installation

### Prerequisites
You will need the following before following the instructions:

1. An OpenAI API key found [here](https://platform.openai.com/api-keys) after creating an account and ensuring it's funded
2. An AWS account with proper permissions to create a Lambda function and API gateway
3. [AWS CLI](https://docs.aws.amazon.com/cli/v1/userguide/cli-chap-configure.html) configured
4. [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) installed

### Server installation steps
1. (Optional) Update the summary prompt - if the default summary prompt does not suit your requirements for output, you can update the `prompt.txt` file and then update the deployment package with the following:

```curl
zip my_deployment_package.zip prompt.txt
```

2. Update the `terraform.tfvars` file with your OpenAI api key (from the step above) and your [desired model](https://platform.openai.com/docs/models), such as `gpt-4o`
3. Run the terraform

```shell
terraform init
terraform plan
terraform apply
```

4. The terraform script will output the AWS server URL and you will need to run this command to get the API key

```shell
terraform output -raw api_key
```

### Usage
- You can request a summary with curl

```curl
curl -X POST \
  <AWS_URL> \
  -H "x-api-key: <AWS_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"article_url": "<URL_TO_SUMMARIZE>"}'
```

- [Apple Shortcut](https://routinehub.co/shortcut/18801/) to contextually send URLs and save the summaries to a clipboard on Apple devices.
