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
            description: 'Deploy the selected image to staging'
        )

        booleanParam(
            name: 'PROMOTE_PRODUCTION',
            defaultValue: false,
            description: 'Request manual production approval'
        )
    }

    environment {
        IMAGE_REPO = 'ghcr.io/muvisi/kk-payments'
        STAGING_NAMESPACE = 'kijani-staging'
        KUBECONFIG = '/etc/kijanikiosk/jenkins/kubeconfig'
    }

    stages {

        stage('Validate Release') {
            steps {
                script {
                    if (!(params.IMAGE_TAG ==~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/)) {
                        error('Invalid image tag')
                    }

                    env.RELEASE_IMAGE = "${env.IMAGE_REPO}:${params.IMAGE_TAG}"

                    echo "Release image: ${env.RELEASE_IMAGE}"
                    echo "Git branch: ${env.GIT_BRANCH ?: 'unknown'}"
                }
            }
        }

        stage('Verify Production Restrictions') {
            steps {
                script {
                    if (params.PROMOTE_PRODUCTION &&
                        env.GIT_BRANCH != 'origin/main') {
                        error(
                            'Production promotion is restricted to main. ' +
                            "Current branch: ${env.GIT_BRANCH}"
                        )
                    }
                }
            }
        }

        stage('Deploy Staging') {
            when {
                expression {
                    params.DEPLOY_STAGING
                }
            }

            steps {
                withEnv(['KUBECONFIG=/etc/kijanikiosk/jenkins/kubeconfig']) {
                    sh '''
                        set -eu

                        echo "===== DEPLOYING STAGING ====="

                        kubectl set image deployment/kk-payments \
                          kk-payments="$RELEASE_IMAGE" \
                          -n "$STAGING_NAMESPACE"

                        kubectl set env deployment/kk-payments \
                          APP_VERSION="$IMAGE_TAG" \
                          -n "$STAGING_NAMESPACE"

                        kubectl rollout status deployment/kk-payments \
                          -n "$STAGING_NAMESPACE" \
                          --timeout=180s

                        echo "Staging deployment completed."
                    '''
                }
            }
        }

        stage('Staging Smoke Test') {
            steps {
                withEnv(['KUBECONFIG=/etc/kijanikiosk/jenkins/kubeconfig']) {
                    sh '''
                        set -eu

                        echo "===== STAGING SMOKE TEST ====="

                        bash scripts/ci/smoke-test.sh \
                          "$STAGING_NAMESPACE" \
                          "$IMAGE_TAG"
                    '''
                }
            }
        }

        stage('Production Approval') {
            when {
                allOf {
                    expression {
                        params.PROMOTE_PRODUCTION
                    }
                    expression {
                        env.GIT_BRANCH == 'origin/main'
                    }
                }
            }

            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input(
                        message: "Approve production deployment of ${env.RELEASE_IMAGE}?",
                        ok: 'Approve Production Deployment',
                        submitter: 'samuel'
                    )
                }
            }
        }

        stage('Promote Production') {
            when {
                allOf {
                    expression {
                        params.PROMOTE_PRODUCTION
                    }
                    expression {
                        env.GIT_BRANCH == 'origin/main'
                    }
                }
            }

            steps {
                script {
                    if (env.GIT_BRANCH != 'origin/main') {
                        error('Production deployment blocked: untrusted branch')
                    }
                }

                withEnv(['KUBECONFIG=/etc/kijanikiosk/jenkins/kubeconfig']) {
                    sh '''
                        set -eu

                        echo "===== PRODUCTION PROMOTION ====="

                        bash scripts/ci/promote-production.sh \
                          "$RELEASE_IMAGE" \
                          "$IMAGE_TAG"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'KijaniKiosk CI/CD pipeline completed successfully.'
        }

        failure {
            echo 'Pipeline FAILED. Review Jenkins logs and Kubernetes rollout status.'
        }

        aborted {
            echo 'Pipeline aborted. Production promotion was not completed.'
        }
    }
}
