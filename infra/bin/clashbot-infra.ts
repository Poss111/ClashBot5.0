#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { ClashbotInfraStack } from '../lib/clashbot-infra-stack';

const app = new cdk.App();

new ClashbotInfraStack(app, 'ClashbotInfraStack', {
  env: {
    region: 'us-east-1'
  }
});

