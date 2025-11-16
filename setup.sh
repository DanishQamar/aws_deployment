# Define a name for your project's root folder
PROJECT_NAME="."

# Create the root folder and all sub-directories
mkdir -p $PROJECT_NAME/service1 $PROJECT_NAME/service2 \
         $PROJECT_NAME/modules/{vpc,security,iam,database,messaging,ecs_cluster,ecs_service}

# Create all the empty files
touch $PROJECT_NAME/service1/Dockerfile \
      $PROJECT_NAME/service1/run.sh \
      $PROJECT_NAME/service2/Dockerfile \
      $PROJECT_NAME/service2/run.sh \
      $PROJECT_NAME/deployment.sh \
      $PROJECT_NAME/main.tf \
      $PROJECT_NAME/variables.tf \
      $PROJECT_NAME/outputs.tf \
      $PROJECT_NAME/modules/vpc/main.tf \
      $PROJECT_NAME/modules/vpc/variables.tf \
      $PROJECT_NAME/modules/vpc/outputs.tf \
      $PROJECT_NAME/modules/security/main.tf \
      $PROJECT_NAME/modules/security/variables.tf \
      $PROJECT_NAME/modules/security/outputs.tf \
      $PROJECT_NAME/modules/iam/main.tf \
      $PROJECT_NAME/modules/iam/variables.tf \
      $PROJECT_NAME/modules/iam/outputs.tf \
      $PROJECT_NAME/modules/database/main.tf \
      $PROJECT_NAME/modules/database/variables.tf \
      $PROJECT_NAME/modules/database/outputs.tf \
      $PROJECT_NAME/modules/messaging/main.tf \
      $PROJECT_NAME/modules/messaging/variables.tf \
      $PROJECT_NAME/modules/messaging/outputs.tf \
      $PROJECT_NAME/modules/ecs_cluster/main.tf \
      $PROJECT_NAME/modules/ecs_cluster/variables.tf \
      $PROJECT_NAME/modules/ecs_cluster/outputs.tf \
      $PROJECT_NAME/modules/ecs_service/main.tf \
      $PROJECT_NAME/modules/ecs_service/variables.tf \
      $PROJECT_NAME/modules/ecs_service/outputs.tf

# Print a success message and show the new structure
echo "✅ Project structure '$PROJECT_NAME' created."
ls -R $PROJECT_NAME