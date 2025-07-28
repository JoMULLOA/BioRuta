"use strict";
import passport from "passport";
import User from "../entity/user.entity.js";
import { ExtractJwt, Strategy as JwtStrategy } from "passport-jwt";
import { ACCESS_TOKEN_SECRET } from "../config/configEnv.js";
import { AppDataSource } from "../config/configDb.js";

const options = {
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
  secretOrKey: ACCESS_TOKEN_SECRET,
};

console.log("🔧 DEBUG - Passport JWT configurado con secretOrKey:", ACCESS_TOKEN_SECRET ? "✅ Definido" : "❌ No definido");

passport.use(
  new JwtStrategy(options, async (jwt_payload, done) => {
    try {
      console.log("🔍 DEBUG - JWT Payload recibido:", jwt_payload);
      
      const userRepository = AppDataSource.getRepository(User);
      
      // Buscar por RUT si está disponible, o por email como respaldo
      let user;
      if (jwt_payload.rut) {
        user = await userRepository.findOne({
          where: { rut: jwt_payload.rut }
        });
        console.log("🔍 DEBUG - Usuario encontrado por RUT:", user ? "SÍ" : "NO");
      } else if (jwt_payload.email) {
        user = await userRepository.findOne({
          where: { email: jwt_payload.email }
        });
        console.log("🔍 DEBUG - Usuario encontrado por EMAIL:", user ? "SÍ" : "NO");
      }

      if (user) {
        console.log("✅ DEBUG - Usuario autenticado:", user.rut);
        return done(null, user);
      } else {
        console.log("❌ DEBUG - Usuario no encontrado en base de datos");
        return done(null, false);
      }
    } catch (error) {
      console.error("❌ DEBUG - Error en estrategia JWT:", error);
      return done(error, false);
    }
  }),
);

export function passportJwtSetup() {
  passport.initialize();
}