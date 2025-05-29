"use strict";
import { EntitySchema } from "typeorm";

const VehiculoSchema = new EntitySchema({
  name: "Vehiculo",
  tableName: "vehiculos",
  columns: {
    patente: {
      type: "varchar",
      primary: true,
      length: 10,
    },
    modelo: {
      type: "varchar",
      nullable: false,
    },
    color: {
      type: "varchar",
      nullable: false,
    },
    nro_asientos: {
      type: "int",
      nullable: false,
    },
    documentacion: {
      type: "varchar",
      nullable: false,
    },
  },
  relations: {
    propietario: {
      type: "many-to-one",
      target: "User", // debe coincidir con el "name" de la entidad User
      joinColumn: {
        name: "id_usuario",
      },
      nullable: false,
      onDelete: "CASCADE",
    },
  },
});

export default VehiculoSchema;
