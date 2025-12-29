import * as path from 'path';
import { Duration, RemovalPolicy, Stack, StackProps, CfnOutput } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as lambdaNode from 'aws-cdk-lib/aws-lambda-nodejs';
import * as apigw from 'aws-cdk-lib/aws-apigateway';
import * as apigwv2 from 'aws-cdk-lib/aws-apigatewayv2';
import * as apigwv2Integrations from 'aws-cdk-lib/aws-apigatewayv2-integrations';
import * as secrets from 'aws-cdk-lib/aws-secretsmanager';
import * as sfn from 'aws-cdk-lib/aws-stepfunctions';
import * as tasks from 'aws-cdk-lib/aws-stepfunctions-tasks';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as sns from 'aws-cdk-lib/aws-sns';
import * as subscriptions from 'aws-cdk-lib/aws-sns-subscriptions';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment';
import * as kms from 'aws-cdk-lib/aws-kms';
import * as budgets from 'aws-cdk-lib/aws-budgets';

export interface ClashbotInfraStackProps extends StackProps {}

export class ClashbotInfraStack extends Stack {
  constructor(scope: Construct, id: string, props?: ClashbotInfraStackProps) {
    super(scope, id, props);

    const envName = this.node.tryGetContext('env') ?? 'prod';
    const isDev = envName === 'dev';
    const prefix = isDev ? 'dev-' : '';

    this.tags.setTag('application', 'ClashBot5.0');
    this.tags.setTag('environment', envName);

    // Data stores
    const tournamentsTable = new dynamodb.Table(this, 'TournamentsTable', {
      tableName: `${prefix}ClashTournaments`,
      partitionKey: { name: 'tournamentId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'startTime', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.DESTROY
    });

    const teamsTable = new dynamodb.Table(this, 'TeamsTable', {
      tableName: `${prefix}ClashTeams`,
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
      tableName: `${prefix}ClashRegistrations`,
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

    const eventsTable = new dynamodb.Table(this, 'EventsTable', {
      tableName: `${prefix}ClashEvents`,
      partitionKey: { name: 'eventId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'timestamp', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.DESTROY
    });

    const usersTable = new dynamodb.Table(this, 'UsersTable', {
      tableName: `${prefix}ClashUsers`,
      partitionKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.DESTROY
    });

    const connectionsTable = new dynamodb.Table(this, 'WebSocketConnectionsTable', {
      tableName: `${prefix}ClashWebSocketConnections`,
      partitionKey: { name: 'connectionId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: RemovalPolicy.DESTROY,
      timeToLiveAttribute: 'ttl'
    });

    const riotSecret = new secrets.Secret(this, 'RiotApiKey', {
      secretName: `${prefix}RIOT-API-KEY`
    });

    // New signing key (separate logical ID to avoid immutable changes on prior key)
    const jwtSignKey = new kms.Key(this, 'AuthJwtSigningKey', {
      enableKeyRotation: false,
      description: 'KMS key for signing auth JWTs',
      keySpec: kms.KeySpec.RSA_2048,
      keyUsage: kms.KeyUsage.SIGN_VERIFY
    });

    const commonEnv = {
      TOURNAMENTS_TABLE: tournamentsTable.tableName,
      TEAMS_TABLE: teamsTable.tableName,
      REGISTRATIONS_TABLE: registrationsTable.tableName,
      USERS_TABLE: usersTable.tableName,
      EVENTS_TABLE: eventsTable.tableName,
      RIOT_SECRET_NAME: riotSecret.secretName,
      KMS_JWT_KEY_ID: jwtSignKey.keyId,
      AWS_NODEJS_CONNECTION_REUSE_ENABLED: '1'
    };

    const sharedNodeModules = [
      '@aws-sdk/client-dynamodb',
      '@aws-sdk/lib-dynamodb',
      '@aws-sdk/client-secrets-manager',
      '@aws-sdk/client-sfn',
      '@aws-sdk/client-apigatewaymanagementapi',
      '@aws-sdk/client-sns',
      '@aws-sdk/client-lambda',
      '@aws-sdk/client-kms',
      'jsonwebtoken'
    ];

    const createLambda = (id: string, entryFile: string, extraEnv: Record<string, string> = {}) => {
      const fn = new lambdaNode.NodejsFunction(this, id, {
        runtime: lambda.Runtime.NODEJS_20_X,
        handler: 'handler',
        entry: path.join(__dirname, '..', '..', 'services', 'src', 'lambdas', entryFile),
        functionName: `${prefix}${id}`,
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
      usersTable.grantReadWriteData(fn);
      eventsTable.grantReadWriteData(fn);
      riotSecret.grantRead(fn);
      jwtSignKey.grantSign(fn);
      jwtSignKey.grantVerify(fn);
      jwtSignKey.grant(fn, 'kms:GetPublicKey');

      return fn;
    };

    // Core lambdas
    const notificationTopic = new sns.Topic(this, 'FetchNotifications', {
      displayName: 'ClashBot Fetch Notifications'
    });
    notificationTopic.addSubscription(new subscriptions.EmailSubscription('rixxroid@gmail.com'));

    const fetchUpcomingFn = createLambda('FetchUpcomingTournamentsFn', 'fetchUpcomingTournaments.ts', {
      NOTIFY_TOPIC_ARN: notificationTopic.topicArn
    });
    notificationTopic.grantPublish(fetchUpcomingFn);
    const loadTournamentFn = createLambda('LoadTournamentFn', 'loadTournament.ts');
    const assignPlayersFn = createLambda('AssignPlayersToTeamsFn', 'assignPlayersToTeams.ts');
    const lockTeamsFn = createLambda('LockTeamsForSubmissionFn', 'lockTeamsForSubmission.ts');
    const deactivatePastFn = createLambda('DeactivatePastTournamentsFn', 'deactivatePastTournaments.ts');

    // API lambdas
    const tournamentsApiFn = createLambda('TournamentsApiFn', 'tournamentsApi.ts');
    const registrationsApiFn = createLambda('RegistrationsApiFn', 'registrationsApi.ts');
    const teamsApiFn = createLambda('TeamsApiFn', 'teamsApi.ts');
    const authBrokerFn = createLambda('AuthBrokerFn', 'authBroker.ts');
    const authValidatorFn = createLambda('AuthValidatorFn', 'authValidator.ts');

    // WebSocket lambdas
    const websocketHandlerFn = createLambda('WebSocketHandlerFn', 'websocketHandler.ts', {
      CONNECTIONS_TABLE: connectionsTable.tableName
    });
    connectionsTable.grantReadWriteData(websocketHandlerFn);

    const broadcastEventFn = createLambda('BroadcastEventFn', 'broadcastEvent.ts', {
      CONNECTIONS_TABLE: connectionsTable.tableName
    });
    connectionsTable.grantReadWriteData(broadcastEventFn);

    // Register tournament lambda with broadcast capability
    const registerTournamentFn = createLambda('RegisterTournamentFn', 'registerTournament.ts', {
      BROADCAST_FUNCTION_NAME: broadcastEventFn.functionName
    });
    broadcastEventFn.grantInvoke(registerTournamentFn);
    const updateTournamentFn = createLambda('UpdateTournamentFn', 'updateTournament.ts', {
      BROADCAST_FUNCTION_NAME: broadcastEventFn.functionName
    });
    broadcastEventFn.grantInvoke(updateTournamentFn);

    // Step Function definition
    const loadTournamentState = new tasks.LambdaInvoke(this, 'LoadTournamentTask', {
      lambdaFunction: loadTournamentFn,
      resultPath: '$.tournament',
      payloadResponseOnly: true,
      payload: sfn.TaskInput.fromObject({
        tournamentId: sfn.JsonPath.stringAt('$.tournamentId')
      })
    });

    const broadcastNotFoundState = new tasks.LambdaInvoke(this, 'BroadcastTournamentNotFound', {
      lambdaFunction: broadcastEventFn,
      payload: sfn.TaskInput.fromObject({
        type: 'tournament.notFound',
        tournamentId: sfn.JsonPath.stringAt('$.tournamentId'),
        error: sfn.JsonPath.stringAt('$.error.Cause')
      }),
      resultSelector: {},
      resultPath: sfn.JsonPath.DISCARD
    });

    const tournamentNotFoundFail = new sfn.Fail(this, 'TournamentNotFoundFail', {
      error: 'TournamentNotFound',
      cause: 'Tournament not found'
    });

    loadTournamentState.addCatch(broadcastNotFoundState, {
      resultPath: '$.error',
      errors: ['States.ALL']
    });
    broadcastNotFoundState.next(tournamentNotFoundFail);

    const assignState = new tasks.LambdaInvoke(this, 'AssignPlayersTask', {
      lambdaFunction: assignPlayersFn,
      resultPath: '$.assignment',
      payloadResponseOnly: true,
      payload: sfn.TaskInput.fromObject({
        tournamentId: sfn.JsonPath.stringAt('$.tournamentId')
      })
    });

    const broadcastAssignState = new tasks.LambdaInvoke(this, 'BroadcastAssignEvent', {
      lambdaFunction: broadcastEventFn,
      payload: sfn.TaskInput.fromObject({
        type: 'players.assigned',
        tournamentId: sfn.JsonPath.stringAt('$.tournamentId'),
        causedBy: sfn.JsonPath.stringAt('$.causedBy'),
        data: {
          tournamentId: sfn.JsonPath.stringAt('$.assignment.tournamentId'),
          teamId: sfn.JsonPath.stringAt('$.assignment.teamId'),
          assignedCount: sfn.JsonPath.numberAt('$.assignment.assignedCount')
        }
      }),
      resultSelector: {},
      resultPath: sfn.JsonPath.DISCARD
    });

    const lockState = new tasks.LambdaInvoke(this, 'LockTeamsTask', {
      lambdaFunction: lockTeamsFn,
      resultPath: '$.lock',
      payloadResponseOnly: true,
      payload: sfn.TaskInput.fromObject({
        tournamentId: sfn.JsonPath.stringAt('$.tournamentId'),
        teamId: sfn.JsonPath.stringAt('$.assignment.teamId')
      })
    });

    const broadcastLockState = new tasks.LambdaInvoke(this, 'BroadcastLockEvent', {
      lambdaFunction: broadcastEventFn,
      payload: sfn.TaskInput.fromObject({
        type: 'teams.locked',
        tournamentId: sfn.JsonPath.stringAt('$.tournamentId'),
        causedBy: sfn.JsonPath.stringAt('$.causedBy'),
        data: {
          tournamentId: sfn.JsonPath.stringAt('$.lock.tournamentId'),
          teamId: sfn.JsonPath.stringAt('$.lock.teamId'),
          status: sfn.JsonPath.stringAt('$.lock.status')
        }
      }),
      resultSelector: {},
      resultPath: sfn.JsonPath.DISCARD
    });

    const workflowDefinition = loadTournamentState
      .next(assignState)
      .next(broadcastAssignState)
      .next(lockState)
      .next(broadcastLockState);

    const assignmentStateMachine = new sfn.StateMachine(this, 'AssignmentWorkflow', {
      definitionBody: sfn.DefinitionBody.fromChainable(workflowDefinition),
      timeout: Duration.minutes(5),
      stateMachineName: `${prefix}AssignmentWorkflow`
    });

    // Lambda to start workflow from API
    const startAssignmentFn = createLambda('StartAssignmentWorkflowFn', 'startAssignmentWorkflow.ts', {
      STATE_MACHINE_ARN: assignmentStateMachine.stateMachineArn,
      BROADCAST_FUNCTION_NAME: broadcastEventFn.functionName
    });
    assignmentStateMachine.grantStartExecution(startAssignmentFn);
    broadcastEventFn.grantInvoke(startAssignmentFn);

    // API Gateway (REST)
    const api = new apigw.RestApi(this, 'ClashApi', {
      restApiName: `${prefix}ClashBot API`,
      deployOptions: {
        stageName: envName
      },
      defaultCorsPreflightOptions: {
        allowOrigins: apigw.Cors.ALL_ORIGINS,
        allowMethods: apigw.Cors.ALL_METHODS,
        allowHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
      },
      defaultMethodOptions: {
        authorizationType: apigw.AuthorizationType.CUSTOM
      }
    });

    const authorizer = new apigw.TokenAuthorizer(this, 'ApiAuthorizer', {
      handler: authValidatorFn,
      resultsCacheTtl: Duration.seconds(0) // no cache to keep it simple
    });

    const tournamentsResource = api.root.addResource('tournaments');
    tournamentsResource.addMethod('GET', new apigw.LambdaIntegration(tournamentsApiFn), {
      authorizer
    });
    tournamentsResource.addMethod('POST', new apigw.LambdaIntegration(registerTournamentFn), {
      authorizer
    });
    const tournamentIdResource = tournamentsResource.addResource('{id}');
    tournamentIdResource.addMethod('GET', new apigw.LambdaIntegration(tournamentsApiFn), {
      authorizer
    });
    tournamentIdResource.addMethod('PUT', new apigw.LambdaIntegration(updateTournamentFn), {
      authorizer
    });
    tournamentIdResource.addResource('registrations').addMethod('POST', new apigw.LambdaIntegration(registrationsApiFn), {
      authorizer
    });
    tournamentIdResource.addResource('assign').addMethod('POST', new apigw.LambdaIntegration(startAssignmentFn), {
      authorizer
    });
    const teamsResource = tournamentIdResource.addResource('teams');
    teamsResource.addMethod('GET', new apigw.LambdaIntegration(teamsApiFn), { authorizer });
    teamsResource.addMethod('POST', new apigw.LambdaIntegration(teamsApiFn), { authorizer });

    const authResource = api.root.addResource('auth');
    authResource.addResource('token').addMethod('POST', new apigw.LambdaIntegration(authBrokerFn), {
      authorizationType: apigw.AuthorizationType.NONE
    });

    // WebSocket API
    const websocketApi = new apigwv2.WebSocketApi(this, 'ClashWebSocketApi', {
      connectRouteOptions: {
        integration: new apigwv2Integrations.WebSocketLambdaIntegration(
          'ConnectIntegration',
          websocketHandlerFn
        )
      },
      disconnectRouteOptions: {
        integration: new apigwv2Integrations.WebSocketLambdaIntegration(
          'DisconnectIntegration',
          websocketHandlerFn
        )
      },
      defaultRouteOptions: {
        integration: new apigwv2Integrations.WebSocketLambdaIntegration(
          'DefaultIntegration',
          websocketHandlerFn
        )
      }
    });

    const websocketStage = new apigwv2.WebSocketStage(this, 'ClashWebSocketStage', {
      webSocketApi: websocketApi,
      stageName: envName,
      autoDeploy: true
    });

    // Grant WebSocket API permission to invoke the handler
    websocketApi.grantManageConnections(websocketHandlerFn);
    websocketApi.grantManageConnections(broadcastEventFn);

    // Update broadcast function with WebSocket endpoint
    // WebSocket endpoint format: wss://{api-id}.execute-api.{region}.amazonaws.com/{stage}
    const websocketEndpoint = `https://${websocketApi.apiId}.execute-api.${this.region}.amazonaws.com/${websocketStage.stageName}`;
    broadcastEventFn.addEnvironment('WEBSOCKET_ENDPOINT', websocketEndpoint);

    // EventBridge schedules
    new events.Rule(this, 'FetchUpcomingSchedule', {
      // 4 AM CST ≈ 10:00 UTC (no DST adjustment)
      schedule: events.Schedule.cron({ minute: '0', hour: '10' }),
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

    new CfnOutput(this, 'WebSocketApiEndpoint', {
      value: `wss://${websocketApi.apiId}.execute-api.${this.region}.amazonaws.com/${websocketStage.stageName}`,
      description: 'WebSocket API endpoint (wss://) for real-time events'
    });

    new CfnOutput(this, 'WebSocketApiId', {
      value: websocketApi.apiId,
      description: 'WebSocket API ID'
    });

    // Budgets: email alerts at $10, $25, $50 for tagged resources
    const budgetThresholds = [10, 25, 50];
    for (const amount of budgetThresholds) {
      new budgets.CfnBudget(this, `ClashBudget${amount}`, {
        budget: {
          budgetType: 'COST',
          timeUnit: 'MONTHLY',
          budgetLimit: { amount, unit: 'USD' },
          costFilters: {
            TagKeyValue: ['application$ClashBot5.0']
          }
        },
        notificationsWithSubscribers: [
          {
            notification: {
              notificationType: 'ACTUAL',
              comparisonOperator: 'GREATER_THAN',
              threshold: amount
            },
            subscribers: [
              {
                subscriptionType: 'EMAIL',
                address: 'rixxroid@gmail.com'
              }
            ]
          }
        ]
      });
    }
  }
}

