import { Router } from "express";
import {
  crearPeticion,
  obtenerPeticiones,
  responderPeticion,
  obtenerMisPeticiones,
  eliminarPeticion,
  obtenerEstadisticas,
  marcarComoSolucionada,
  verificarPeticionActiva,
  verificarPeticionPendiente,
} from "../controllers/peticionSupervision.controller.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";

const router = Router();

// Aplicar autenticación a todas las rutas
router.use(authenticateJwt);

// Rutas para usuarios
router.post("/", crearPeticion);
router.get("/mis-peticiones", obtenerMisPeticiones);
router.get("/verificar-activa", verificarPeticionActiva);
router.get("/verificar-pendiente", verificarPeticionPendiente);
router.delete("/:id", eliminarPeticion);

// Rutas para administradores
router.get("/", obtenerPeticiones);
router.put("/:id/responder", responderPeticion);
router.put("/:id/solucionada", marcarComoSolucionada);
router.get("/estadisticas", obtenerEstadisticas);

export default router;