extends RefCounted
static func combined(game: Node) -> void:
	var homes: Array[Vector2] = [game.field.headquarters(0).pos,game.field.headquarters(1).pos]
	game.units.clear(); game.field.buildings.clear(); game.field.queues.clear(); game.field.next_building_id=1
	for team in 2:
		game.field.add_building({"pos":homes[team],"team":team,"type":0,"hp":2400.0})
		for kind in range(1,5):
			game.field.add_building({"pos":game.base_plot(team,kind),"team":team,"type":kind,"hp":900.0})
			game.field.buildings[-1].heavy=true
		for kind in [0,0,1,2,3,4,7,8,9,10,11]: game.spawn(kind,team,game.field.headquarters(team).pos+Vector2(400 if team==0 else -400,-260+kind*45))
	game.field.supply[0]=5000; game.field.supply[1]=5000; game.field.fuel[0]=1000; game.field.fuel[1]=1000
	game.active=null; game.selected.clear(); game.selected_building={}; game.refresh_panel()
