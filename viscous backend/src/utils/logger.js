const format = (level, message, meta) => {
  const ts = new Date().toISOString();
  if (!meta) return `[${ts}] [${level}] ${message}`;
  return `[${ts}] [${level}] ${message} ${JSON.stringify(meta)}`;
};

export const logger = {
  info(message, meta) {
    console.log(format("INFO", message, meta));
  },
  warn(message, meta) {
    console.warn(format("WARN", message, meta));
  },
  error(message, meta) {
    console.error(format("ERROR", message, meta));
  }
};
