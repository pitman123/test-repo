pipeline {
    agent none // This specifies that the pipeline will not use any pre-configured agent globally

    stages {
        stage('Build') {
            agent {
                dockerContainer {
                    image 'python:3.9' // Using the official Python image from Docker Hub
                    // Ensure other necessary options are set if required
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
