"use strict";
import express from "express";
import { isAdmin } from "../middlewares/authorization.middleware.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";
import { deleteUser, getUser, getUsers, updateUser, searchUser, buscarRut, getMisVehiculos, calcularCalificacion, obtenerPromedioGlobal, actualizarTokenFCM, getHistorialTransacciones, calificarUsuario } from "../controllers/user.controller.js";
import { AppDataSource } from "../config/configDb.js";
import User from "../entity/user.entity.js";

const router = express.Router();

// Middleware para autenticar y verificar si el usuario es administrador
router.use(authenticateJwt);
//router.use(isAdmin);

// Rutas protegidas que requieren autenticación
router.get("/busqueda", searchUser);
router.get("/busquedaRut", buscarRut);

//Ruta calificacion de usuario
router.post("/calcularCalificacion", calcularCalificacion);

// Nueva ruta para calificar usuarios con estrellas
router.post("/calificar", calificarUsuario);

// Nueva ruta para obtener el promedio global
router.get("/promedioGlobal", obtenerPromedioGlobal);

// Rutas de usuario
router.get("/", getUsers);
router.get("/detail/", getUser);
router.get("/mis-vehiculos", getMisVehiculos); // Nueva ruta para obtener vehículos del usuario
router.get("/historial-transacciones", getHistorialTransacciones); // Nueva ruta para historial
router.patch("/actualizar", updateUser);
router.patch("/fcm-token", actualizarTokenFCM); // Nueva ruta para actualizar token FCM
router.delete("/detail/", isAdmin, deleteUser); // Solo administradores pueden eliminar usuarios

export default router;