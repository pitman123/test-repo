node {
    checkout scm  // Fetch source code from the SCM repository

    // Start the PostgreSQL container as a "sidecar"
    docker.image('postgres:15').withRun('-e POSTGRES_DB=myapp_db ' +
                                        '-e POSTGRES_USER=myapp_user ' +
                                        '-e POSTGRES_PASSWORD=myapp_password ' +
                                        '-p 5432:5432') { postgresContainer ->
        
        /* Wait until the PostgreSQL service is ready to accept connections */
        sh "while ! docker exec ${postgresContainer.id} pg_isready -h localhost -p 5432; do sleep 1; done"

        // Launch the main Ruby container linked to the PostgreSQL container
        docker.image('ruby:3.2.2').inside("--link ${postgresContainer.id}:db") {
            sh 'ruby -v'
            
            /* Install dependencies, for example, using Bundler */
            //sh 'bundle install'
            
            /* Set the environment variable to connect to the database */
             sh 'export DATABASE_URL=postgres://myapp_user:myapp_password@db:5432/myapp_db'
            
            /* Run database migrations or other operations */
           // sh 'bundle exec rake db:migrate'
            
            /* Execute tests */
           // sh 'bundle exec rake test'
        }
    }
}
