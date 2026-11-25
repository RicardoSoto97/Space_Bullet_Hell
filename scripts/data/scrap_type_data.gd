class_name ScrapTypeData
extends Resource
## Un tipo de chatarra (GDD 6.2). El precio es provisional y se ajustará jugando.

@export var id: StringName
@export var display_name: String
## Precio base en créditos por unidad.
@export var price: int = 1
## Color del trozo de chatarra en el nivel.
@export var color: Color = Color.GRAY
## Si brilla (las chatarras raras).
@export var glows: bool = false
