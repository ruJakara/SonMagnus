# scripts/resources/WeaponResource.gd
class_name WeaponResource
extends Resource

@export var weapon_name: String = "Железный меч"
@export var weapon_type: String = "sword"
@export var base_damage: float = 15.0
@export var crit_chance: float = 0.1
@export var attack_speed: float = 1.0
@export var block_power: float = 0.5  # 50% блокировки
@export var durability: float = 100.0
@export var max_durability: float = 100.0

