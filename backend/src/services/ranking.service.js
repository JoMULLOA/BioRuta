"use strict";
import { AppDataSource } from "../config/configDb.js";
import user from "../entity/user.entity.js";

export async function getRankingService() {
  try {
    const userRepository = AppDataSource.getRepository(user);

    const ranking = await userRepository.find({
      order: {
        puntuacion: "DESC",
      },
      take: 10,
    });
    console.log("Ranking obtenido:", ranking);
    if (!ranking || ranking.length === 0) return [null, "No hay usuarios en el ranking"];

    const rankingData = ranking.map(({ password, puntuacion, ...user }) => ({
      ...user,
      puntuacion: puntuacion ?? 0, // Si puntuacion es null, asignar 0
    }));

    return [rankingData, null];
  } catch (error) {
    console.error("Error al obtener el ranking:", error);
    return [null, "Error interno del servidor"];
  }
}