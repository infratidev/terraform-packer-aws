#!/usr/bin/env bash
#Author:Andrei
set -eo pipefail

#Vars
packerjsonpath="../terraform-packer-build-aws"
terranetworkpath="../terraform-packer-network-aws"
terradeploypath="../terraform-packer-deploy-aws"
packerhclfilename="packer.pkr.hcl"

case "$1" in
  all)

      echo "terraform init => packer network infrastructure"
      cd $terranetworkpath && terraform init      
      echo ""

      echo "terraform plan => packer network infrastructure"
      cd $terranetworkpath && terraform plan 
      echo ""

      echo "terraform apply => packer network infrastructure"
      cd $terranetworkpath && terraform apply --auto-approve
      echo ""

      echo "Retrieve vpc_id"
      vpc_id=$(cd $terranetworkpath && terraform output -raw vpc_packer_id)
      printf $vpc_id
      echo ""

      echo "Retrieve subnet_id"
      subnet_id=$(cd $terranetworkpath && terraform output -json public_subnets_packer | jq -r '.[0]')
      printf $subnet_id
      echo ""

      echo "Change vpc_id Packer.json"
      sed -i '/vpc_id/s/.*/vpc_id="'$vpc_id'"/' $packerjsonpath/packer.pkr.hcl && packer fmt $packerjsonpath/$packerhclfilename
      echo ""

      echo "Change subnet_id Packer.json"
      sed -i '/subnet_id/s/.*/subnet_id="'$subnet_id'"/' $packerjsonpath/packer.pkr.hcl && packer fmt $packerjsonpath/$packerhclfilename
      echo ""

      echo "Validate Packer.json"
      cd $packerjsonpath && packer validate $packerhclfilename

      if [ $? -eq 0 ]; then
        cd $packerjsonpath && packer build $packerhclfilename
        echo ""
      else
        echo "Validate failed"    
        echo ""
      fi

      echo "Retrieve AMI_ID packer_manifest.json"
      AMI_ID=$(cd $packerjsonpath && jq -r '.builds[-1].artifact_id' packer_manifest.json | cut -d ":" -f2)
      echo $AMI_ID
      echo ""

      echo "Change AMI variable to Deploy"
      sed -i '/packer_ami_id/s/.*/packer_ami_id="'$AMI_ID'"/' $terradeploypath/terraform.tfvars
      echo ""
      
      echo "terraform init => packer deploy infrastructure"
      cd $terradeploypath && terraform init      
      echo ""

      echo "terraform plan => packer deploy infrastructure"
      cd $terradeploypath && terraform plan 
      echo ""

      echo "terraform apply => packer deploy infrastructure"
      cd $terradeploypath && terraform apply --auto-approve

      if [ $? -eq 0 ]; then
        echo ""
        echo "##################################"
        echo "Deploy Infrastructure. Suceeded..."
        echo "##################################"
        echo ""
      else
        echo ""
        echo "###################################################"
        echo "Deploy Infrastructure. Failed. Something went wrong..."
        echo "###################################################"
        echo ""
     fi
    
  ;;
  destroy)
    
      echo "Retrieve AMI_ID packer_manifest.json"
      AMI_ID=$(cd $packerjsonpath && jq -r '.builds[-1].artifact_id' packer_manifest.json | cut -d ":" -f2)

      echo "Remove Snap and AMI"
      ./delete-ami.sh $AMI_ID
      echo "" 

      echo "terraform destroy => packer network infrastructure"
      cd $terranetworkpath && terraform destroy --auto-approve
      echo ""

      echo "terraform destroy => packer deploy infrastructure"
      cd $terradeploypath && terraform destroy --auto-approve

      if [ $? -eq 0 ]; then
        echo ""
        echo "##########################################"
        echo "All Infrastructure Destroyed. Suceeded..."
        echo "##########################################"
      else
        echo ""
        echo "#############################################################"
        echo "All Infrastructure Destroyed. Failed. Something went wrong..."
        echo "#############################################################"
        echo ""
     fi
 ;;
  *)
     printf "terraform-packer-aws.sh (all|destroy)"
     echo
  ;;
esac
exit 0