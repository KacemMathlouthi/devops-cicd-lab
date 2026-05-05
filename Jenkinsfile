pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        UV_CACHE_DIR = "${WORKSPACE}/.uv-cache"
        IMAGE_NAME   = 'kacemmathlouthi/devops-cicd-lab'
        IMAGE_TAG    = "${env.BUILD_NUMBER}"
        IMAGE_REF    = "${IMAGE_NAME}:${IMAGE_TAG}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git rev-parse --short HEAD > .git-sha && cat .git-sha'
            }
        }

        stage('Install') {
            steps {
                sh 'uv --version'
                sh 'uv sync --frozen'
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'uv run pytest --junitxml=test-results.xml'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-results.xml'
                    archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
                }
            }
        }

        stage('Static Analysis') {
            steps {
                withSonarQubeEnv('SonarCloud') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.token=$SONAR_AUTH_TOKEN \
                          -Dsonar.scm.revision=$(cat .git-sha)
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    docker build \
                      --label org.opencontainers.image.revision=$(cat .git-sha) \
                      --label org.opencontainers.image.source=https://github.com/KacemMathlouthi/devops-cicd-lab \
                      -t $IMAGE_REF \
                      -t $IMAGE_NAME:latest \
                      .
                '''
            }
        }

        stage('Image Scanning') {
            steps {
                sh '''
                    trivy image \
                      --severity HIGH,CRITICAL \
                      --exit-code 0 \
                      --format table \
                      $IMAGE_REF | tee trivy-report.txt
                    trivy image \
                      --severity CRITICAL \
                      --exit-code 1 \
                      --ignore-unfixed \
                      --format table \
                      $IMAGE_REF
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
                }
            }
        }

        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKERHUB_USER',
                    passwordVariable: 'DOCKERHUB_TOKEN'
                )]) {
                    sh '''
                        echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin
                        docker push $IMAGE_REF
                        docker push $IMAGE_NAME:latest
                        docker logout
                    '''
                }
            }
        }

        stage('Infrastructure (Terraform)') {
            environment {
                TF_VAR_k8s_endpoint_override = 'https://devops-cicd-lab-control-plane:6443'
            }
            steps {
                dir('infra/terraform') {
                    sh '''
                        if [ -f /host-tf-state/terraform.tfstate ]; then
                            cp /host-tf-state/terraform.tfstate ./terraform.tfstate
                        fi

                        terraform init -input=false -no-color
                        terraform fmt -check -no-color
                        terraform validate -no-color

                        terraform plan -input=false -no-color -out=tfplan
                        terraform show -no-color tfplan
                        terraform apply -input=false -no-color tfplan

                        cp ./terraform.tfstate /host-tf-state/terraform.tfstate
                    '''
                }
            }
        }

        stage('Configure & Deploy (Ansible)') {
            steps {
                withCredentials([file(credentialsId: 'kind-kubeconfig', variable: 'KUBECONFIG_FILE')]) {
                    dir('deploy/ansible') {
                        sh '''
                            export KUBECONFIG="$KUBECONFIG_FILE"
                            export IMAGE_TAG="$BUILD_NUMBER"
                            ansible-playbook site.yml
                        '''
                    }
                }
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    set -e
                    URL="http://app.127-0-0-1.nip.io/"
                    for i in $(seq 1 30); do
                        code=$(curl -s -o /tmp/smoke-body -w '%{http_code}' \
                            --connect-to app.127-0-0-1.nip.io:80:devops-cicd-lab-control-plane:80 \
                            "$URL" || true)
                        if [ "$code" = "200" ]; then
                            echo "Smoke test OK (HTTP $code) against $URL"
                            cat /tmp/smoke-body
                            echo
                            exit 0
                        fi
                        echo "attempt $i/30: HTTP $code, retrying in 2s..."
                        sleep 2
                    done
                    echo "Smoke test FAILED — $URL did not return 200 after 60s"
                    exit 1
                '''
            }
        }
    }

    post {
        always {
            echo "Build #${env.BUILD_NUMBER} finished with status: ${currentBuild.currentResult}"
        }
        cleanup {
            cleanWs notFailBuild: true
        }
    }
}
