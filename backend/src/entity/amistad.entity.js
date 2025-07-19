"use strict";
import { EntitySchema } from "typeorm";

const AmistadSchema = new EntitySchema({
  name: "Amistad",
  tableName: "amistades",
  columns: {
    id: {
      type: "int",
      primary: true,
      generated: true,
    },
    rutUsuario1: {
      type: "varchar",
      length: 12,
      nullable: false,
    },
    rutUsuario2: {
      type: "varchar",
      length: 12,
      nullable: false,
    },
    fechaAmistad: {
      type: "timestamp with time zone",
      default: () => "CURRENT_TIMESTAMP",
      nullable: false,
    },
    bloqueado: {
      type: "boolean",
      default: false,
      nullable: false,
    },
    rutBloqueador: {
      type: "varchar",
      length: 12,
      nullable: true,
    },
  },
  relations: {
    usuario1: {
      type: "many-to-one",
      target: "User",
      joinColumn: {
        name: "rutUsuario1",
        referencedColumnName: "rut",
      },
      eager: true,
    },
    usuario2: {
      type: "many-to-one",
      target: "User", 
      joinColumn: {
        name: "rutUsuario2",
        referencedColumnName: "rut",
      },
      eager: true,
    },
  },
  indices: [
    {
      name: "IDX_AMISTAD_USUARIO1",
      columns: ["rutUsuario1"],
    },
    {
      name: "IDX_AMISTAD_USUARIO2",
      columns: ["rutUsuario2"],
    },
    {
      name: "UNIQUE_AMISTAD",
      columns: ["rutUsuario1", "rutUsuario2"],
      unique: true,
    },
  ],
});

export default AmistadSchema;
