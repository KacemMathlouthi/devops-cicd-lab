pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        UV_CACHE_DIR = "${WORKSPACE}/.uv-cache"
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
