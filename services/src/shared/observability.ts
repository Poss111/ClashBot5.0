import { metricScope, MetricsLogger, Unit } from 'aws-embedded-metrics';
import { logError } from './logger';

const namespace = process.env.METRICS_NAMESPACE ?? 'ClashOps';
const envName = process.env.ENV_NAME ?? 'prod';
const serviceName = process.env.SERVICE_NAME ?? 'clash-api';

type LambdaHandler<TEvent = any, TResult = any> = (event: TEvent, context?: any) => Promise<TResult>;

interface ApiMetricsOptions<TEvent = any, TResult = any> {
  source?: 'rest' | 'ws';
  defaultRoute?: string;
  feature?: string | ((event: TEvent, result?: TResult) => string | undefined);
}

const statusClass = (code: number) => `${Math.floor(code / 100)}xx`;

const recordApiMetrics = <TEvent, TResult>(
  metrics: MetricsLogger,
  event: TEvent,
  result: TResult | undefined,
  opts: ApiMetricsOptions<TEvent, TResult>,
  elapsedMs: number,
  failure: boolean
) => {
  const route =
    (event as any)?.resource ||
    (event as any)?.path ||
    opts.defaultRoute ||
    'unknown';
  const httpCode = typeof (result as any)?.statusCode === 'number' ? (result as any).statusCode : failure ? 500 : 200;
  const httpStatusClass = statusClass(httpCode);

  metrics.setNamespace(namespace);
  metrics.setProperty('route', route);
  metrics.setProperty('service', serviceName);
  metrics.setProperty('env', envName);
  metrics.setProperty('httpStatus', httpCode);
  metrics.setProperty('statusClass', httpStatusClass);
  metrics.setProperty('source', opts.source ?? 'rest');
  metrics.setProperty('requestId', (event as any)?.requestContext?.requestId);
  metrics.setProperty('traceId', (event as any)?.headers?.['x-amzn-trace-id'] ?? (event as any)?.headers?.['X-Amzn-Trace-Id']);
  metrics.setProperty('user', (event as any)?.requestContext?.authorizer?.principalId ?? null);

  // Emit with multiple dimension sets in one call to avoid overrides.
  const dimensionSets: Array<Record<string, string>> = [
    { Service: serviceName, Env: envName },
    { Service: serviceName, Env: envName, Route: route },
    { Service: serviceName, Env: envName, Route: route, StatusClass: httpStatusClass }
  ];

  const feature =
    typeof opts.feature === 'function'
      ? opts.feature(event, result)
      : opts.feature;
  if (feature) {
    dimensionSets.push({ Service: serviceName, Env: envName, Feature: feature });
    metrics.setProperty('feature', feature);
  }

  // setDimensions accepts multiple dimension sets; avoids serialization issues like "[object Object]"
  metrics.setDimensions(...dimensionSets);

  metrics.putMetric('Requests', 1, Unit.Count);
  metrics.putMetric('LatencyMs', elapsedMs, Unit.Milliseconds);
  if (httpCode >= 400 || failure) {
    metrics.putMetric('Errors', 1, Unit.Count);
  }
};

export const withApiMetrics =
  <TEvent = any, TResult = any>(options: ApiMetricsOptions<TEvent, TResult> = {}) =>
  (handler: LambdaHandler<TEvent, TResult>): LambdaHandler<TEvent, TResult> =>
    metricScope((metrics: MetricsLogger) => async (event: TEvent, context?: any) => {
      const start = Date.now();
      try {
        const result = await handler(event, context);
        recordApiMetrics(metrics, event, result, options, Date.now() - start, false);
        return result;
      } catch (err) {
        logError('withApiMetrics.failed', { error: String(err) });
        recordApiMetrics(metrics, event, undefined, options, Date.now() - start, true);
        throw err;
      }
    });

export const withFunctionMetrics =
  <TEvent = any, TResult = any>(operation: string) =>
  (handler: LambdaHandler<TEvent, TResult>): LambdaHandler<TEvent, TResult> =>
    metricScope((metrics: MetricsLogger) => async (event: TEvent, context?: any) => {
      const start = Date.now();
      metrics.setNamespace(namespace);
      metrics.putDimensions({ Service: serviceName, Env: envName, Operation: operation });
      metrics.setProperty('operation', operation);
      metrics.setProperty('service', serviceName);
      metrics.setProperty('env', envName);
      try {
        const result = await handler(event, context);
        metrics.putMetric('Invocations', 1, Unit.Count);
        metrics.putMetric('DurationMs', Date.now() - start, Unit.Milliseconds);
        return result;
      } catch (err) {
        metrics.putMetric('Invocations', 1, Unit.Count);
        metrics.putMetric('Failures', 1, Unit.Count);
        metrics.putMetric('DurationMs', Date.now() - start, Unit.Milliseconds);
        logError('withFunctionMetrics.failed', { operation, error: String(err) });
        throw err;
      }
    });


