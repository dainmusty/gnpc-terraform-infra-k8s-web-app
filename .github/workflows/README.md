name: Terraform Plan and Apply

on:
  pull_request:
    branches:
      - dev
      - staging
  push:
    branches:
      - dev
      - staging

env:
  AWS_REGION: us-east-1
  TERRAFORM_VERSION: '1.6.6'

jobs:
  set-env:
    runs-on: ubuntu-latest
    outputs:
      env: ${{ steps.set_env.outputs.env }}
    steps:
      - name: Determine environment
        id: set_env
        run: |
          if [[ "${GITHUB_REF##*/}" == "dev" ]]; then
            echo "env=dev" >> $GITHUB_OUTPUT
          else
            echo "env=staging" >> $GITHUB_OUTPUT
          fi

  terraform:
    needs: set-env
    runs-on: ubuntu-latest
    defaults:
      run:
        shell: bash

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Install TFLint
        run: |
          curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

      - name: Run TFLint
        working-directory: terraform-infra/environments/${{ needs.set-env.outputs.env }}
        run: |
          tflint --init
          tflint --enable-rule=aws_instance_invalid_type

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        working-directory: terraform-infra/environments/${{ needs.set-env.outputs.env }}
        run: terraform init -input=false

      - name: Terraform Plan or Apply
        working-directory: terraform-infra/environments/${{ needs.set-env.outputs.env }}
        run: |
          if [[ "${{ github.event_name }}" == "push" ]]; then
            terraform apply -auto-approve
          else
            terraform plan



.
├── ansible/
│   ├── inventory/
│   │   └── aws_ec2.yml       # Your dynamic inventory file
│   ├── playbooks/
│   │   └── setup-prometheus.yml
│   └── roles/                # Optional: for reusable tasks
├── terraform-infra/
│   └── environments/
│       └── dev/
│           └── main.tf
└── .github/workflows/
    └── terraform-ansible.yml  # This workflow file
