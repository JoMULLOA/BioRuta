"use strict";
import express from "express";
import { getRanking } from "../controllers/ranking.controller.js";


const router = express.Router();
// Ruta para obtener el ranking de usuarios
router.get("/", getRanking);

export default router;