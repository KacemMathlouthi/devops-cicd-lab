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
