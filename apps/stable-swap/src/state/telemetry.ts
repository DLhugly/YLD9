export type FillEvent = {
  venue: string;
  estOut: bigint;
  realizedOut: bigint;
  netBps: number;
  error?: string;
};

export const sendTelemetry = async (ev: FillEvent) => {
  // MVP: console only
  // eslint-disable-next-line no-console
  console.log("telemetry", ev);
};



