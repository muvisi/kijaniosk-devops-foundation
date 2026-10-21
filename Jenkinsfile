pipeline {
    agent any

    options {
        timeout(time: 10, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        choice(
            name: 'FAULT_STAGE',
            choices: [
                'None',
                'Lint',
                'Build',
                'Test',
                'Security Audit',
                'Archive',
                'Publish'
            ],
            description: 'Choose a stage for intentional fault injection.'
        )
    }

    environment {
        NODE_IMAGE = 'node:22.14.0-alpine3.21'
        NEXUS_URL = 'http://localhost:8081'
        NEXUS_NPM_REPOSITORY = 'kijanikiosk-npm'
    }

    stages {
        stage('Lint') {
            steps {
                script {
                    if (params.FAULT_STAGE == 'Lint') {
                        error('Intentional fault injection: Lint')
                    }
                }

                sh '''
                    docker run --rm --network host \
                        --user "$(id -u):$(id -g)" \
                        -e HOME=/tmp \
                        -e npm_config_cache=/tmp/npm-cache \
                        -v "$WORKSPACE:/work" \
                        -w /work \
                        "$NODE_IMAGE" \
                        npm run lint
                '''
            }
        }

        stage('Build') {
            steps {
                script {
                    if (params.FAULT_STAGE == 'Build') {
                        error('Intentional fault injection: Build')
                    }

                    env.PACKAGE_VERSION =
                        "1.0.0-${env.GIT_COMMIT.take(7)}"
                }

                sh '''
                    docker run --rm --network host \
                        --user "$(id -u):$(id -g)" \
                        -e HOME=/tmp \
                        -e npm_config_cache=/tmp/npm-cache \
                        --env PACKAGE_VERSION \
                        -v "$WORKSPACE:/work" \
                        -w /work \
                        "$NODE_IMAGE" \
                        sh -ec '
                            npm ci
                            npm version "$PACKAGE_VERSION" --no-git-tag-version
                            npm run build
                            mkdir -p artifacts
                            npm pack --pack-destination artifacts
                        '
                '''
            }
        }

        stage('Verify') {
            parallel {
                stage('Test') {
                    steps {
                        script {
                            if (params.FAULT_STAGE == 'Test') {
                                error('Intentional fault injection: Test')
                            }
                        }

                        sh '''
                            docker run --rm --network host \
                                --user "$(id -u):$(id -g)" \
                                -e HOME=/tmp \
                                -e npm_config_cache=/tmp/npm-cache \
                                -v "$WORKSPACE:/work" \
                                -w /work \
                                "$NODE_IMAGE" \
                                node --test \
                                    --test-reporter=junit \
                                    --test-reporter-destination=test-results.xml
                        '''
                    }
                }

                stage('Security Audit') {
                    steps {
                        script {
                            if (params.FAULT_STAGE == 'Security Audit') {
                                error('Intentional fault injection: Security Audit')
                            }
                        }

                        sh '''
                            docker run --rm --network host \
                                --user "$(id -u):$(id -g)" \
                                -e HOME=/tmp \
                                -e npm_config_cache=/tmp/npm-cache \
                                -v "$WORKSPACE:/work" \
                                -w /work \
                                "$NODE_IMAGE" \
                                npm audit --audit-level=high
                        '''
                    }
                }
            }
        }

        stage('Archive') {
            steps {
                script {
                    if (params.FAULT_STAGE == 'Archive') {
                        error('Intentional fault injection: Archive')
                    }
                }

                archiveArtifacts(
                    artifacts: 'artifacts/*.tgz',
                    fingerprint: true
                )
            }
        }

        stage('Publish') {
            steps {
                script {
                    if (params.FAULT_STAGE == 'Publish') {
                        error('Intentional fault injection: Publish')
                    }
                }

                withCredentials([
                    usernamePassword(
                        credentialsId: 'nexus-publish',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASSWORD'
                    )
                ]) {
                    sh '''
                        set +x

                        docker run --rm --network host \
                            --user "$(id -u):$(id -g)" \
                            -e HOME=/tmp \
                            -e npm_config_cache=/tmp/npm-cache \
                            --env NEXUS_USER \
                            --env NEXUS_PASSWORD \
                            --env NEXUS_URL \
                            --env NEXUS_NPM_REPOSITORY \
                            -v "$WORKSPACE:/work" \
                            -w /work \
                            "$NODE_IMAGE" \
                            sh -ec '
                                trap "rm -f .npmrc" EXIT

                                AUTH=$(printf "%s:%s" \
                                    "$NEXUS_USER" "$NEXUS_PASSWORD" \
                                    | base64 | tr -d "\\n")

                                printf "%s\\n" \
                                    "registry=${NEXUS_URL}/repository/${NEXUS_NPM_REPOSITORY}/" \
                                    "//localhost:8081/repository/${NEXUS_NPM_REPOSITORY}/:always-auth=true" \
                                    "//localhost:8081/repository/${NEXUS_NPM_REPOSITORY}/:_auth=${AUTH}" \
                                    > .npmrc

                                npm publish \
                                    --registry="${NEXUS_URL}/repository/${NEXUS_NPM_REPOSITORY}/"
                            '
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'rm -f .npmrc'

            junit(
                testResults: 'test-results.xml',
                allowEmptyResults: true
            )

            echo 'Cleanup and test-result collection completed.'
        }

        success {
            echo "SUCCESS: Published kijanikiosk version ${env.PACKAGE_VERSION}."
            echo "Nexus registry: ${env.NEXUS_URL}/repository/${env.NEXUS_NPM_REPOSITORY}/"
            echo "Expected tarball URL: ${env.NEXUS_URL}/repository/${env.NEXUS_NPM_REPOSITORY}/kijanikiosk/-/kijanikiosk-${env.PACKAGE_VERSION}.tgz"
        }

        failure {
            echo 'FAILURE: Pipeline failed. Check the stage logs above.'
        }

        changed {
            echo 'BUILD STATUS CHANGED: Compare this result with the previous build.'
        }
    }
}
