import { Router } from "express";
import healthRouter from "./health.routes.js";
import locationRouter from "./location.routes.js";
import authRouter from "./auth.routes.js";
import routeRouter from "./route.routes.js";
import userRouter from "./user.routes.js";

const apiRouter = Router();

apiRouter.use("/health", healthRouter);
apiRouter.use("/location", locationRouter);
apiRouter.use("/auth", authRouter);
apiRouter.use("/route", routeRouter);
apiRouter.use("/users", userRouter);

export default apiRouter;
