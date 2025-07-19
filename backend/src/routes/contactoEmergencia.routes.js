"use strict";
import express from "express";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";
import {
  createContactoEmergencia,
  getContactosEmergencia,
  updateContactoEmergencia,
  deleteContactoEmergencia,
} from "../controllers/contactoEmergencia.controller.js";

const router = express.Router();

// Middleware para autenticar todas las rutas
router.use(authenticateJwt);

/**
 * @route GET /api/contactos-emergencia
 * @desc Obtener todos los contactos de emergencia del usuario autenticado
 * @access Private
 */
router.get("/", getContactosEmergencia);

/**
 * @route POST /api/contactos-emergencia
 * @desc Crear un nuevo contacto de emergencia
 * @access Private
 */
router.post("/", createContactoEmergencia);

/**
 * @route PUT /api/contactos-emergencia/:id
 * @desc Actualizar un contacto de emergencia específico
 * @access Private
 */
router.put("/:id", updateContactoEmergencia);

/**
 * @route DELETE /api/contactos-emergencia/:id
 * @desc Eliminar un contacto de emergencia específico
 * @access Private
 */
router.delete("/:id", deleteContactoEmergencia);

export default router;
