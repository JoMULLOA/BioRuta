"use strict";
import express from "express";
import { getRanking, getRankingClasificaciones } from "../controllers/ranking.controller.js";


const router = express.Router();
// Ruta para obtener el ranking de usuarios por puntos
router.get("/", getRanking);
// Ruta para obtener el ranking de usuarios por clasificaciones
router.get("/clasificaciones", getRankingClasificaciones);

export default router;