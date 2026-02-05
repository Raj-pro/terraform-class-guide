@echo off
REM AWS Credentials Setup Script for Windows
REM This script helps you set up AWS credentials as environment variables

echo === AWS Credentials Setup ===
echo.
echo This script will set your AWS credentials as environment variables.
echo Note: These credentials will only persist for the current command prompt session.
echo.

REM Prompt for AWS Access Key ID
set /p AWS_ACCESS_KEY_ID="Enter your AWS Access Key ID: "

REM Prompt for AWS Secret Access Key
set /p AWS_SECRET_ACCESS_KEY="Enter your AWS Secret Access Key: "

echo.
echo √ AWS credentials have been set for this command prompt session.
echo.
echo You can now run Terraform commands:
echo   terraform init
echo   terraform plan
echo   terraform apply
echo.
echo To verify your credentials are set, run:
echo   echo %AWS_ACCESS_KEY_ID%
echo.
