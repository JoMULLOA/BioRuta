"use strict";
import { getRankingService, getRankingClasificacionesService } from "../services/ranking.service.js";

export async function getRanking(req, res) {
  try {
    const [ranking, errorRanking] = await getRankingService();

    if (errorRanking) return res.status(404).json({ message: errorRanking });

    ranking.length === 0
      ? res.status(204).send()
      : res.status(200).json({ message: "Ranking encontrado", ranking });
  } catch (error) {
    console.error("Error al obtener el ranking:", error);
    res.status(500).json({ message: "Error interno del servidor" });
  }
}

export async function getRankingClasificaciones(req, res) {
  try {
    const [ranking, errorRanking] = await getRankingClasificacionesService();

    if (errorRanking) return res.status(404).json({ message: errorRanking });

    ranking.length === 0
      ? res.status(204).send()
      : res.status(200).json({ message: "Ranking de clasificaciones encontrado", ranking });
  } catch (error) {
    console.error("Error al obtener el ranking de clasificaciones:", error);
    res.status(500).json({ message: "Error interno del servidor" });
  }
}

