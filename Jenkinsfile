pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    parameters {
        string(
            name: 'IMAGE_TAG',
            defaultValue: '1.0.0-b563111',
            description: 'Immutable GHCR image tag'
        )
        booleanParam(
            name: 'DEPLOY_STAGING',
            defaultValue: true,
            description: 'Deploy image to staging'
        )
        booleanParam(
            name: 'PROMOTE_PRODUCTION',
            defaultValue: false,
            description: 'Allow manual production approval'
        )
    }

    environment {
        IMAGE_REPO = 'ghcr.io/muvisi/kk-payments'
        STAGING_NAMESPACE = 'kijani-staging'
    }

    stages {
        stage('Validate Release') {
            steps {
                script {
                    if (!(params.IMAGE_TAG ==~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/)) {
                        error('Invalid image tag')
                    }

                    env.RELEASE_IMAGE = "${env.IMAGE_REPO}:${params.IMAGE_TAG}"
                }

                echo "Release image: ${env.RELEASE_IMAGE}"
            }
        }

        stage('Deploy Staging') {
            when {
                expression { params.DEPLOY_STAGING }
            }

            steps {
                withCredentials([
                    file(
                        credentialsId: 'kijani-kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    sh '''
                        set -eu

                        kubectl set image deployment/kk-payments \
                          kk-payments="$RELEASE_IMAGE" \
                          -n "$STAGING_NAMESPACE"

                        kubectl set env deployment/kk-payments \
                          APP_VERSION="$IMAGE_TAG" \
                          -n "$STAGING_NAMESPACE"

                        kubectl rollout status deployment/kk-payments \
                          -n "$STAGING_NAMESPACE" \
                          --timeout=180s
                    '''
                }
            }
        }

        stage('Staging Smoke Test') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kijani-kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    sh '''
                        set -eu

                        bash scripts/ci/smoke-test.sh \
                          "$STAGING_NAMESPACE" "$IMAGE_TAG"
                    '''
                }
            }
        }

        stage('Production Approval') {
            when {
                expression { params.PROMOTE_PRODUCTION }
            }

            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input(
                        message: "Promote ${env.RELEASE_IMAGE} to production?",
                        ok: 'Approve Production Deployment'
                    )
                }
            }
        }

        stage('Promote Production') {
            when {
                expression { params.PROMOTE_PRODUCTION }
            }

            steps {
                withCredentials([
                    file(
                        credentialsId: 'kijani-kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    sh '''
                        set -eu

                        bash scripts/ci/promote-production.sh \
                          "$RELEASE_IMAGE" "$IMAGE_TAG"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'KijaniKiosk pipeline completed successfully.'
        }

        failure {
            echo 'Pipeline failed. Review deployment and smoke-test logs.'
        }
    }
}
