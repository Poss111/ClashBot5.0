type LogLevel = 'info' | 'warn' | 'error' | 'debug';

export const log = (level: LogLevel, message: string, meta: Record<string, unknown> = {}) => {
  const entry = {
    level,
    message,
    timestamp: new Date().toISOString(),
    ...meta
  };

  // CloudWatch will store this as a single line JSON object that Kibana/Grafana can parse
  console.log(JSON.stringify(entry));
};

export const logInfo = (message: string, meta?: Record<string, unknown>) => log('info', message, meta ?? {});
export const logWarn = (message: string, meta?: Record<string, unknown>) => log('warn', message, meta ?? {});
export const logError = (message: string, meta?: Record<string, unknown>) => log('error', message, meta ?? {});
export const logDebug = (message: string, meta?: Record<string, unknown>) => log('debug', message, meta ?? {});

