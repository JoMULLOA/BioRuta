"use strict";
import { Router } from "express";
import userRoutes from "./user.routes.js";
import authRoutes from "./auth.routes.js";
import chatRoutes from "./chat.routes.js";
import rankingRoutes from "./ranking.routes.js";
import vehiculoRoutes from "./vehiculo.routes.js";
import amistadRoutes from "./amistad.routes.js";
import notificacionRoutes from "./notificacion.routes.js";

const router = Router();

router
    .use("/auth", authRoutes)
    .use("/user", userRoutes)
    .use("/chat", chatRoutes)
    .use("/ranking", rankingRoutes)
    .use("/vehiculos", vehiculoRoutes)
    .use("/amistad", amistadRoutes)
    .use("/notificaciones", notificacionRoutes);
export default router;