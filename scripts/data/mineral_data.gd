class_name MineralData
extends Resource
## Un mineral puro (GDD 7.5): sale de refinar chatarra en la refinería o de las minas.
## Vale más que la chatarra y solo se vende en el puerto comercial de la base.

@export var id: StringName
@export var display_name: String
## Precio en créditos por unidad.
@export var price: int = 15
@export var color: Color = Color.WHITE
## Chatarra de la que se refina y cuántas unidades hacen falta para 1 mineral.
@export var source_scrap: StringName
@export var source_amount: int = 1
## Probabilidad relativa de salir en una mina (0 = no se extrae).
@export var mine_weight: float = 0.0
