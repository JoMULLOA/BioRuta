"use strict";
import express from "express";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";
import {
  createVehiculo,
  getMisVehiculos,
  updateVehiculo,
  deleteVehiculo,
} from "../controllers/vehiculo.controller.js";

const router = express.Router();

// Todas las rutas requieren autenticación
router.use(authenticateJwt);

// Rutas de vehículos
router.post("/crear", createVehiculo);
router.get("/mis-vehiculos", getMisVehiculos);
router.patch("/:patente", updateVehiculo);
router.delete("/:patente", deleteVehiculo);

export default router;
