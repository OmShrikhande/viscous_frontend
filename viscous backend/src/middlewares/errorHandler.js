export const errorHandler = (error, _req, res, _next) => {
  const statusCode = 500;

  res.status(statusCode).json({
    ok: false,
    message: error.message ?? "Internal server error"
  });
};
