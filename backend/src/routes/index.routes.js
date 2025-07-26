"use strict";
import { Router } from "express";
import userRoutes from "./user.routes.js";
import authRoutes from "./auth.routes.js";
import chatRoutes from "./chat.routes.js";
import rankingRoutes from "./ranking.routes.js";
import vehiculoRoutes from "./vehiculo.routes.js";
import amistadRoutes from "./amistad.routes.js";
import notificacionRoutes from "./notificacion.routes.js";
import contactoEmergenciaRoutes from "./contactoEmergencia.routes.js";
import peticionSupervisionRoutes from "./peticionSupervision.routes.js";
import viajeRoutes from "./viaje.routes.js";
import transaccionRoutes from "./transaccion.routes.js";

const router = Router();

router
    .use("/auth", authRoutes)
    .use("/user", userRoutes)
    .use("/chat", chatRoutes)
    .use("/ranking", rankingRoutes)
    .use("/vehiculos", vehiculoRoutes)
    .use("/amistad", amistadRoutes)
    .use("/notificaciones", notificacionRoutes)
    .use("/contactos-emergencia", contactoEmergenciaRoutes)
    .use("/peticiones-supervision", peticionSupervisionRoutes)
    .use("/viajes", viajeRoutes)
    .use("/transacciones", transaccionRoutes)
export default router;