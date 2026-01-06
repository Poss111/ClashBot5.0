declare module 'aws-embedded-metrics' {
  export const Unit: { [key: string]: string };
  export type Unit = keyof typeof Unit | string;

  export interface MetricsLogger {
    setNamespace(namespace: string): void;
    putDimensions(dimensions: Record<string, string>): void;
    setDimensions(...dimensions: Array<Record<string, string>>): void;
    putMetric(name: string, value: number, unit?: Unit): void;
    setProperty(key: string, value: any): void;
  }

  export function metricScope<T extends (...args: any[]) => any>(
    handler: (metrics: MetricsLogger) => T
  ): T;
}

