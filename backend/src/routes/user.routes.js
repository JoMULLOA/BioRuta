"use strict";
import express from "express";
import { isAdmin } from "../middlewares/authorization.middleware.js";
import { authenticateJwt } from "../middlewares/authentication.middleware.js";
import { deleteUser, getGarzones, getUser, getUsers, updateUser } from "../controllers/user.controller.js";
import { AppDataSource } from "../config/configDb.js";
import User from "../entity/user.entity.js";

const router = express.Router();

// Middleware para autenticar y verificar si el usuario es administrador
router.use(authenticateJwt);
//router.use(isAdmin);

// Rutas de usuario
router.get("/", getUsers);
router.get("/detail/", getUser);
router.patch("/detail/", updateUser);
router.delete("/detail/", deleteUser);

export default router;