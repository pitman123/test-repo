pipeline {
    agent none // This specifies that the pipeline will not use any pre-configured agent

    stages {
        stage('Build') {
            agent {
                docker {
                    image 'python:3.9' // Using the official Python image from Docker Hub
                    args '-u root' // Run as root if necessary (not recommended for production)
                }
            }
            steps {
                // Execute Python commands or scripts
                sh 'python --version'
                sh 'pip install -r requirements.txt'
                sh 'python my_script.py'
            }
        }
    }
}
