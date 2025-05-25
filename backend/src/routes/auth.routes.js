"use strict";
import { Router } from "express";
import { login, logout, register } from "../controllers/auth.controller.js";
import { sendCode, sendCoder, verifyCode } from "../controllers/verification.controller.js";
const router = Router();

router
  .post("/login", login)
  .post("/register", register)
  .post("/logout", logout)
  .post("/send-code", sendCode)
  .post("/send-coder", sendCoder)
  .post("/verify-code", verifyCode);
export default router;