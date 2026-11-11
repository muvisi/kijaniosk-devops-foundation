pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Verify Kubernetes Access') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kijani-kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    sh '''
                        set -eu

                        echo "===== STAGING DEPLOYMENT ====="
                        kubectl get deployment kk-payments \
                          -n kijani-staging

                        echo "===== STAGING ACCESS ====="
                        test "$(kubectl auth can-i patch deployments \
                          -n kijani-staging)" = "yes"

                        echo "===== PRODUCTION ACCESS ====="
                        test "$(kubectl auth can-i patch \
                          deployment/kk-payments -n default)" = "yes"

                        echo "===== PRODUCTION RESTRICTIONS ====="
                        test "$(kubectl auth can-i delete deployments \
                          -n default)" = "no"

                        echo "Kubernetes authentication verified."
                    '''
                }
            }
        }
    }
}
