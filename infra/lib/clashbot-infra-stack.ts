import * as path from 'path';
import { Duration, RemovalPolicy, Stack, StackProps, CfnOutput } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as lambdaNode from 'aws-cdk-lib/aws-lambda-nodejs';
import * as apigw from 'aws-cdk-lib/aws-apigateway';
import * as secrets from 'aws-cdk-lib/aws-secretsmanager';
import * as sfn from 'aws-cdk-lib/aws-stepfunctions';
import * as tasks from 'aws-cdk-lib/aws-stepfunctions-tasks';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment';

export interface ClashbotInfraStackProps extends StackProps {}

export class ClashbotInfraStack extends Stack {
  constructor(scope: Construct, id: string, props?: ClashbotInfraStackProps) {
    super(scope, id, props);

    // Data stores
    const tournamentsTable = new dynamodb.Table(this, 'TournamentsTable', {
      tableName: 'ClashTournaments',
      partitionKey: { name: 'tournamentId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'startTime', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.DESTROY
    });

    const teamsTable = new dynamodb.Table(this, 'TeamsTable', {
      tableName: 'ClashTeams',
      partitionKey: { name: 'teamId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'tournamentId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.DESTROY
    });

    teamsTable.addGlobalSecondaryIndex({
      indexName: 'teams-by-tournament',
      partitionKey: { name: 'tournamentId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'teamId', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL
    });

    const registrationsTable = new dynamodb.Table(this, 'RegistrationsTable', {
      tableName: 'ClashRegistrations',
      partitionKey: { name: 'tournamentId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'playerId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.DESTROY
    });

    registrationsTable.addGlobalSecondaryIndex({
      indexName: 'team-by-tournament',
      partitionKey: { name: 'tournamentId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'teamId', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL
    });

    const riotSecret = new secrets.Secret(this, 'RiotApiKey', {
      secretName: 'RIOT-API-KEY'
    });

    const commonEnv = {
      TOURNAMENTS_TABLE: tournamentsTable.tableName,
      TEAMS_TABLE: teamsTable.tableName,
      REGISTRATIONS_TABLE: registrationsTable.tableName,
      RIOT_SECRET_NAME: riotSecret.secretName,
      AWS_NODEJS_CONNECTION_REUSE_ENABLED: '1'
    };

    const sharedNodeModules = [
      '@aws-sdk/client-dynamodb',
      '@aws-sdk/lib-dynamodb',
      '@aws-sdk/client-secrets-manager',
      '@aws-sdk/client-sfn'
    ];

    const createLambda = (id: string, entryFile: string, extraEnv: Record<string, string> = {}) => {
      const fn = new lambdaNode.NodejsFunction(this, id, {
        runtime: lambda.Runtime.NODEJS_20_X,
        handler: 'handler',
        entry: path.join(__dirname, '..', '..', 'services', 'src', 'lambdas', entryFile),
        bundling: {
          target: 'node20',
          format: lambdaNode.OutputFormat.CJS,
          minify: false,
          externalModules: [],
          nodeModules: sharedNodeModules
        },
        timeout: Duration.seconds(20),
        environment: {
          ...commonEnv,
          ...extraEnv
        }
      });

      tournamentsTable.grantReadWriteData(fn);
      teamsTable.grantReadWriteData(fn);
      registrationsTable.grantReadWriteData(fn);
      riotSecret.grantRead(fn);

      return fn;
    };

    // Core lambdas
    const fetchUpcomingFn = createLambda('FetchUpcomingTournamentsFn', 'fetchUpcomingTournaments.ts');
    const registerTournamentFn = createLambda('RegisterTournamentFn', 'registerTournament.ts');
    const assignPlayersFn = createLambda('AssignPlayersToTeamsFn', 'assignPlayersToTeams.ts');
    const lockTeamsFn = createLambda('LockTeamsForSubmissionFn', 'lockTeamsForSubmission.ts');
    const deactivatePastFn = createLambda('DeactivatePastTournamentsFn', 'deactivatePastTournaments.ts');

    // API lambdas
    const tournamentsApiFn = createLambda('TournamentsApiFn', 'tournamentsApi.ts');
    const registrationsApiFn = createLambda('RegistrationsApiFn', 'registrationsApi.ts');
    const teamsApiFn = createLambda('TeamsApiFn', 'teamsApi.ts');

    // Step Function definition
    const registerState = new tasks.LambdaInvoke(this, 'RegisterTournamentTask', {
      lambdaFunction: registerTournamentFn,
      resultPath: '$.register'
    });

    const assignState = new tasks.LambdaInvoke(this, 'AssignPlayersTask', {
      lambdaFunction: assignPlayersFn,
      resultPath: '$.assignment'
    });

    const lockState = new tasks.LambdaInvoke(this, 'LockTeamsTask', {
      lambdaFunction: lockTeamsFn,
      resultPath: '$.lock'
    });

    const workflowDefinition = registerState.next(assignState).next(lockState);

    const assignmentStateMachine = new sfn.StateMachine(this, 'AssignmentWorkflow', {
      definitionBody: sfn.DefinitionBody.fromChainable(workflowDefinition),
      timeout: Duration.minutes(5)
    });

    // Lambda to start workflow from API
    const startAssignmentFn = createLambda('StartAssignmentWorkflowFn', 'startAssignmentWorkflow.ts', {
      STATE_MACHINE_ARN: assignmentStateMachine.stateMachineArn
    });
    assignmentStateMachine.grantStartExecution(startAssignmentFn);

    // API Gateway (REST)
    const api = new apigw.RestApi(this, 'ClashApi', {
      restApiName: 'ClashBot API',
      deployOptions: {
        stageName: 'prod'
      }
    });

    const tournamentsResource = api.root.addResource('tournaments');
    tournamentsResource.addMethod('GET', new apigw.LambdaIntegration(tournamentsApiFn));
    const tournamentIdResource = tournamentsResource.addResource('{id}');
    tournamentIdResource.addMethod('GET', new apigw.LambdaIntegration(tournamentsApiFn));
    tournamentIdResource.addResource('registrations').addMethod('POST', new apigw.LambdaIntegration(registrationsApiFn));
    tournamentIdResource.addResource('assign').addMethod('POST', new apigw.LambdaIntegration(startAssignmentFn));
    tournamentIdResource.addResource('teams').addMethod('GET', new apigw.LambdaIntegration(teamsApiFn));

    // EventBridge schedules
    new events.Rule(this, 'FetchUpcomingSchedule', {
      schedule: events.Schedule.rate(Duration.days(1)),
      targets: [new targets.LambdaFunction(fetchUpcomingFn)]
    });

    new events.Rule(this, 'DeactivatePastSchedule', {
      schedule: events.Schedule.rate(Duration.hours(1)),
      targets: [new targets.LambdaFunction(deactivatePastFn)]
    });

    // Frontend hosting bucket + CloudFront
    const siteBucket = new s3.Bucket(this, 'FrontendBucket', {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      versioned: false,
      removalPolicy: RemovalPolicy.DESTROY,
      autoDeleteObjects: true
    });

    const distribution = new cloudfront.Distribution(this, 'FrontendDistribution', {
      defaultRootObject: 'index.html',
      defaultBehavior: {
        origin: new origins.S3Origin(siteBucket),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS
      },
      errorResponses: [
        {
          httpStatus: 403,
          responseHttpStatus: 200,
          responsePagePath: '/index.html',
          ttl: Duration.minutes(5)
        },
        {
          httpStatus: 404,
          responseHttpStatus: 200,
          responsePagePath: '/index.html',
          ttl: Duration.minutes(5)
        }
      ]
    });

    // Deploy built Angular assets (expects `frontend/dist/clashbot`)
    new s3deploy.BucketDeployment(this, 'DeployFrontend', {
      sources: [s3deploy.Source.asset(path.join(__dirname, '..', '..', 'frontend', 'dist', 'clashbot'))],
      destinationBucket: siteBucket,
      distribution,
      distributionPaths: ['/*']
    });

    new CfnOutput(this, 'CloudFrontDomain', {
      value: distribution.domainName,
      description: 'CloudFront distribution domain for the frontend'
    });

    new CfnOutput(this, 'FrontendBucketName', {
      value: siteBucket.bucketName,
      description: 'S3 bucket used for hosting the frontend'
    });
  }
}

