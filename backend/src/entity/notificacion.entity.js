"use strict";
import { EntitySchema } from "typeorm";

const Notificacion = new EntitySchema({
  name: "Notificacion",
  tableName: "notificaciones",
  columns: {
    id: {
      primary: true,
      type: "int",
      generated: true,
    },
    tipo: {
      type: "varchar",
      length: 50,
    },
    titulo: {
      type: "varchar",
      length: 200,
    },
    mensaje: {
      type: "text",
    },
    leida: {
      type: "boolean",
      default: false,
    },
    fechaCreacion: {
      type: "timestamp",
      createDate: true,
    },
    rutReceptor: {
      type: "varchar",
    },
    rutEmisor: {
      type: "varchar",
      nullable: true,
    },
    viajeId: {
      type: "varchar",
      nullable: true,
      comment: "ID del viaje en MongoDB"
    },
    datos: {
      type: "json",
      nullable: true,
    },
  },
  relations: {
    receptor: {
      target: "User",
      type: "many-to-one",
      joinColumn: {
        name: "rutReceptor",
      },
    },
    emisor: {
      target: "User",
      type: "many-to-one",
      joinColumn: {
        name: "rutEmisor",
      },
      nullable: true,
    },
    // Eliminamos la relación con Viaje ya que está en MongoDB
  },
});

export default Notificacion;
