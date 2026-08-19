pipeline {
    agent any

    parameters {
        booleanParam(name: 'DESTROY_AND_REBUILD', defaultValue: true, description: 'Run terraform destroy, then full fresh rebuild')
        booleanParam(name: 'REBUILD_IMAGE', defaultValue: false, description: 'Rebuild the Packer golden image first, else reuse')
    }

    environment {
        // Securely pull the vault password from Jenkins Credentials store
        ANSIBLE_VAULT_PASS = credentials('ANSIBLE_VAULT_PASS_REAL')
    }

    stages {
        stage('Prepare Workspace') {
            steps {
                // 1. Checkout latest source code from Git
                checkout scm
                
                // 2. Clean temporary build artifacts, preserving Packer image and Terraform state memory
                sh 'git clean -ffdx -e packer/output -e terraform/.terraform -e terraform/*.tfstate*'
            }
        }

        stage('Packer Golden Image') {
            when {
                expression { params.REBUILD_IMAGE == true || !fileExists('packer/output/alma10-golden.qcow2') }
            }
            steps {
                dir('packer') {
                    sh 'packer init .'
                    sh 'packer build .'
                }
            }
        }

        stage('Terraform Infrastructure') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                    script {
                        if (params.DESTROY_AND_REBUILD == true) {
                            sh 'terraform destroy -auto-approve'
                        }
                    }
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('Ansible CIS Hardening') {
            steps {
                dir('ansible') {
                    // Temporarily inject the secret Jenkins password into vaultpass.txt
                    sh 'echo "$ANSIBLE_VAULT_PASS" > vaultpass.txt'
                    
                    // Download role dependencies dynamically
                    sh 'ansible-galaxy install -r requirements.yml'
                    
                    // Execute Level 1 remediation with Level 3 Extra-Vars (-e) and Tag Skipping
                    sh 'ansible-playbook -i inventory/hosts playbook.yml --vault-password-file vaultpass.txt -e "rhel10cis_pass_max_days=30" --skip-tags "level2-server,level2-workstation"'
                    
                    // Remove secret password file immediately after execution for security
                    sh 'rm -f vaultpass.txt'
                }
            }
        }

        stage('Archive Audit Reports') {
            steps {
                dir('ansible') {
                    // Archive the Goss JSON audit reports directly in the Jenkins UI
                    archiveArtifacts artifacts: '*.json', allowEmptyArchive: true
                }
            }
        }
    }
}
