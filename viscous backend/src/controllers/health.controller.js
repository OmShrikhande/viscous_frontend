export const healthCheck = (_req, res) => {
  res.status(200).json({
    ok: true,
    service: "viscous-backend",
    timestamp: new Date().toISOString()
  });
};
