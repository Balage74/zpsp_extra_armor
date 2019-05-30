/*
TODO
usehudot letenni a jobb alsó sarokba az itempickup mellé


*/


#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <zombie_plague_special>

/*================================================================================
 [Defines]
=================================================================================*/ 
//#define is_valid_player(%1) (1 <= %1 <= 32) 
//#define is_valid_alive_player ((1 <= %1 <= g_maxplayers) && is_user_connected(%1) && is_user_alive(%1))
//#pragma dynamic 32768  
new const PLUGIN[] = "[ZP][ITEM]Armor"
new const VERSION[] = "1.0"
new const AUTHOR[] = "Furion"

#define is_valid_player(%1) (1 <= %1 <= g_maxplayers && is_user_connected(%1)) 
#define is_valid_real_player(%1) (1 <= %1 <= g_maxplayers && is_user_connected(%1) && !is_user_bot(%1) && !is_user_hltv(%1)) 

/*================================================================================
 [Tasks]
=================================================================================*/ 
/*================================================================================
 [global vars]
=================================================================================*/
// Class ID
new g_item_id
new const g_item_name[] = "Armor"
new g_maxplayers
new bool:g_lastzombie[33]
new bool:g_lasthuman[33]
new bool:g_firstzombie[33]

new gGMsgItemPickup;
//new gGMsgStatusIcon;

//new const g_item_useteam[] = "Human" //same with register extra item!! its for use picked  entity
//new const g_item_freeteam[] = "Classic"			//real names need from zpsp_zombieclasses not use Zombie here:D
new const g_item_dropteam[] = "Classic Zombie"
new const g_item_pickupteam[] = "Zombie|Human"


new const gEntClassname[ ] = "armor_entity";
//precaches
new const szModelKit[ ] = "models/w_kevlar.mdl";
new const szPickupSound[ ] = "zombie_plague/ammodrop.wav";
new const szSound[] = "items/tr_kevlar.wav"
new const szIcon[] = "suit_full"
enum _: iCoords
{
	x = 0,
	y,
	z
};

new Float:gHudxPos = 0.07
new Float:gHudyPos = 0.250

//define value
const g_max_value = 100

//cvars
new cvar_dropteam,cvar_pickupteam
new cvar_item_roundlimit_player,cvar_item_roundlimit_global,cvar_item_maplimit
new cvar_icon,cvar_hud,cvar_sound
new g_pcvar_dropteam[128],g_pcvar_pickupteam[128]
new g_pcvar_item_roundlimit_player,g_pcvar_item_roundlimit_global,g_pcvar_item_maplimit
new g_pcvar_icon,g_pcvar_hud,g_pcvar_sound

new g_item[33]
new g_item_used[33]
new bool:g_info[33]


new g_roundlimit
new g_maplimit
/*================================================================================
 [Init, CFG and Precache]
=================================================================================*/

public plugin_precache()
{
	cvar_dropteam = register_cvar("zp_armor_dropteam","Classic Zombie")	
	cvar_pickupteam = register_cvar("zp_armor_pikupteam","Zombie|Human")	
	cvar_item_roundlimit_player = register_cvar("zp_armor_roundlimit","5")	
	cvar_item_roundlimit_global = register_cvar("zp_armor_roundlimit_g","10")
	cvar_item_maplimit = register_cvar("zp_armor_maplimit","50")	
	cvar_icon = register_cvar("zp_armor_icon","1")	
	cvar_hud = register_cvar("zp_armor_hud","1")
	cvar_sound = register_cvar("zp_armor_sound","1")	
	precache_sound(szSound)
	precache_sound(szPickupSound)	
	precache_model( szModelKit );

	
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	get_pcvar_string(cvar_dropteam,g_pcvar_dropteam,charsmax(g_pcvar_dropteam))
	get_pcvar_string(cvar_pickupteam,g_pcvar_pickupteam,charsmax(g_pcvar_pickupteam))	
	g_pcvar_item_roundlimit_player = get_pcvar_num(cvar_item_roundlimit_player)
	g_pcvar_item_roundlimit_global = get_pcvar_num(cvar_item_roundlimit_global)	
	g_pcvar_item_maplimit = get_pcvar_num(cvar_item_maplimit)	
	g_pcvar_icon = get_pcvar_num(cvar_icon)	
	g_pcvar_hud	 = get_pcvar_num(cvar_hud)
	g_pcvar_sound	 = get_pcvar_num(cvar_sound)	
	register_event("DeathMsg", "event_death", "a")		
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	gGMsgItemPickup = get_user_msgid( "ItemPickup" );	
//	gGMsgStatusIcon = get_user_msgid("StatusIcon")
	g_maxplayers = get_maxplayers()	
	g_item_id = zp_register_extra_item(g_item_name, 20, ZP_TEAM_HUMAN)
	register_forward( FM_Touch, "forward_FM_Touch" );	
}
public plugin_cfg()
{
	g_roundlimit = 0
	g_maplimit = 0
}
public OnConfigsExecuted()
{	

}
/***********************************************************
NATIVES
**********************************************************/
public plugin_natives()
{
	register_native("give_item_ex", "native_give_item_ex", 1)	//add 'amount'  item to player
	register_native("remove_item_ex", "native_remove_item_ex", 1)//remove 'amount' item from player 
	register_native("use_item_ex", "native_use_item_ex", 1)// force to use jut if he not limited	
//	register_native("item_ex_quantity", "native_item_ex_quantity", 1)//picked quantity	

//	register_native("item_ex_expire", "native_item_ex_expire", 1)	//If have timelimit
//	register_native("item_ex_cooldown", "native_item_ex_cooldown", 1)	//if have cooldown
}
public native_give_item_ex(id,const item_name[],amount)
{
	if (!is_valid_player(id)) 	return false;
	if (equal(item_name,g_item_name))
	{
		(!amount) ?	(g_item[id]++) : (g_item[id] += amount)
		if(g_info[id] == false){
			client_print_color(id ,print_team_default,  "^4 Felvettél egy %s-t . További információkért írd be chatben a '^1%s^4' szót",g_item_name,g_item_name) 
			g_info[id] = true
		}
		if (g_pcvar_hud) UTIL_Send_PickupHud( id )
		if (g_pcvar_icon )	UTIL_Send_PickupMessage( id, szIcon );		
		if(g_pcvar_sound)	emit_sound( id, CHAN_ITEM, szPickupSound, VOL_NORM, ATTN_NORM, 0 , PITCH_NORM );	
		return true;		
	}
	return false;
}

public native_remove_item_ex(id,const item_name[],amount)
{
	if (!is_valid_player(id)) return false;
	if (equal(item_name,g_item_name))
	{
		if(amount)	((g_item[id] >= amount) ? (g_item[id] -= amount) : (g_item[id] = 0));
		else (g_item[id] > 0) ? (g_item[id]--) : (g_item[id] = 0)
		return true;
	}
	return false
}

public native_use_item_ex(id,const item_name[],set)
{
	if (!is_valid_player(id)) 	return false;
	if (equal(item_name,g_item_name) )
	{ 	
		if(set)	add_armor(id)
		else remove_armor(id)
		return true
	}
	return false	
}




/*================================================================================
 [MAIN ]
=================================================================================*/

public zp_extra_item_selected_pre(id, itemid)
{
	if (itemid == g_item_id)
	{
	
		if (g_pcvar_item_roundlimit_player == 0 ||
			g_pcvar_item_roundlimit_global == 0 ||
			g_pcvar_item_maplimit == 0		) return ZP_PLUGIN_SUPERCEDE
		if (g_item_used[id]>=g_pcvar_item_roundlimit_player) return ZP_PLUGIN_HANDLED
		if (g_roundlimit>=g_pcvar_item_roundlimit_global) return 	ZP_PLUGIN_HANDLED
		if (g_maplimit>=g_pcvar_item_maplimit) return 			ZP_PLUGIN_HANDLED
		if (get_user_armor(id) > 99) return ZP_PLUGIN_HANDLED	
	}
	return PLUGIN_CONTINUE
}

public zp_extra_item_selected(id, itemid)
{
	if(itemid == g_item_id)
	{
	
	
		if (g_pcvar_item_roundlimit_player == 0 ||
			g_pcvar_item_roundlimit_global == 0 ||
			g_pcvar_item_maplimit == 0		) return ZP_PLUGIN_SUPERCEDE
		else if (g_item_used[id]>=g_pcvar_item_roundlimit_player) return ZP_PLUGIN_HANDLED		
		else if (g_roundlimit>=g_pcvar_item_roundlimit_global) return ZP_PLUGIN_HANDLED			
		else if (g_maplimit>=g_pcvar_item_maplimit) return ZP_PLUGIN_HANDLED			
		else if (get_user_armor(id) > 99) return ZP_PLUGIN_HANDLED
		else
		{
			native_use_item_ex(id,g_item_name,1)
		}
	}
	return PLUGIN_HANDLED
}


public client_connect(id)
{
	g_item_used[id] = 0
	g_item[id]= 0
	g_info[id] = false
	g_lastzombie[id] = false
	g_lasthuman[id]= false
	g_firstzombie[id] = false
 } 
public client_putinserver(id)
{

}
public zp_user_humanize_post(id)
{

}
public zp_user_infected_post(id)
{

	if (zp_get_user_zombie_class(id) != -1 && zp_get_user_first_zombie(id)) g_firstzombie[id] = true



}


public zp_user_last_zombie(id)
{

	g_lastzombie[id] = true
}

public zp_user_last_human(id)
{


	g_lasthuman[id] = true

}
public event_death()
{
	new killer = read_data(1)
	new victim = read_data(2)
	if (!is_valid_player(victim)) return PLUGIN_HANDLED;	
	if (victim == killer) return PLUGIN_HANDLED;
	if (g_pcvar_item_roundlimit_player == 0 ||
		g_pcvar_item_roundlimit_global == 0 ||
		g_pcvar_item_maplimit == 0		) return PLUGIN_HANDLED;
	if (equali(g_pvar_dropteam,"None") == true ) return PLUGIN_HANDLED;
	
	new iCast[64]
	if(zp_get_user_zombie(victim))
	{
		if (zp_get_user_zombie_class(victim) == -1) zp_get_special_class_name(victim, iCast, charsmax(iCast)) 	
		else zp_get_zombie_class_name (zp_get_user_zombie_class(victim),  iCast, charsmax( iCast))	
	}
	else
	{
		zp_get_special_class_name(victim, iCast, charsmax(iCast)) 
	}	
	if (
	(containi(g_item_dropteam	, iCast) > -1)  ||
	((containi(g_item_dropteam,"Last Human") > -1) && (g_lasthuman[victim] == true))||
	((containi(g_item_dropteam,"Last Zombie") > -1) && (g_lastzombie[victim] == true))||
	((containi(g_item_dropteam,"First Zombie") >-1) && (g_firstzombie[victim] == true))
	) 
	{
	
	new ran = random_num(0,1)
	if (ran == 1)
	{
		static Float:flOrigin[ iCoords ];
		pev( victim, pev_origin, flOrigin );
		new iEnt = engfunc( EngFunc_CreateNamedEntity, engfunc( EngFunc_AllocString, "info_target" ) );
		/* --| Modify the origin a little bit. This is calculated to be set on floor */
		flOrigin[ z ] -= 36; 
		flOrigin[ x ] -= -3; 
		flOrigin[ x ] -= 3; 		
		engfunc( EngFunc_SetOrigin, iEnt, flOrigin );
		if( !pev_valid( iEnt ) )
		{
			return PLUGIN_HANDLED;
		}
		set_pev( iEnt, pev_classname, gEntClassname );
	//	set_pev( iEnt, pev_team, "CS_TEAM_CT" );
		engfunc( EngFunc_SetModel, iEnt, szModelKit );
		dllfunc( DLLFunc_Spawn, iEnt );
		set_pev( iEnt, pev_solid, SOLID_TRIGGER );
		set_pev( iEnt, pev_movetype, MOVETYPE_TOSS );//MOVETYPE_NONE
		engfunc( EngFunc_SetSize, iEnt, Float:{ -3.160000, -3.660000, -0.050000 }, Float:{ 3.470000, 1.780000, 3.720000 } );   //Float:{ -3.160000, -3.660000, -0.050000 }, Float:{ 11.470000, 12.780000, 6.720000 } );
		engfunc( EngFunc_DropToFloor, iEnt );	
	
	}	
	return PLUGIN_HANDLED;	
}


public client_disconnected(id)
{
	g_item_used[id] = 0
	g_item[id]= 0
	g_info[id] = false
	g_lastzombie[id] = false
	g_lasthuman[id]= false
	g_firstzombie[id] = false
}
public event_round_start()
{
	g_roundlimit = 0
	remove_allentity()
	for (new id; id <= g_maxplayers; id++)
	{
		if (is_user_connected(id))
		{
		
			g_item_used[id] = 0
			g_lastzombie[id] = false
			g_lasthuman[id]= false
			g_firstzombie[id] = false
		}
	}
}

public zp_round_started(gamemode, id)
{

}

public zp_round_ended(winteam)
{

}
/***********************************************************
EXTRAITEM  FUNCTIONS (messages,save,load)
**********************************************************/
public forward_FM_Touch( iEnt, id )
{
	if( !pev_valid( iEnt ) || !is_user_alive(id) || is_user_bot(id) ) return FMRES_IGNORED;
	if (equali(g_pvar_pickupteam,"None") == true ) return FMRES_IGNORED;
	
		new iCast[64]
	if(zp_get_user_zombie(id))
	{
		if (zp_get_user_zombie_class(id) == -1) zp_get_special_class_name(id, iCast, charsmax(iCast)) 	
		else zp_get_zombie_class_name (zp_get_user_zombie_class(id),  iCast, charsmax( iCast))	
	}
	else
	{
		zp_get_special_class_name(id, iCast, charsmax(iCast)) 
	}	
	if (
	(containi(g_item_pickupteam	, iCast) > -1)  ||
	((containi(g_item__pickupteam,"Last Human") > -1) && (g_lasthuman[id] == true))||
	((containi(g_item__pickupteam,"Last Zombie") > -1) && (g_lastzombie[id] == true))||
	((containi(g_item__pickupteam,"First Zombie") >-1) && (g_firstzombie[id] == true))
	) 
	{
	
		new szClassname[ 32 ];
		pev( iEnt, pev_classname, szClassname, charsmax( szClassname ) );
		if( !equal( szClassname, gEntClassname ) )	return FMRES_IGNORED;

		native_give_item_ex(id,g_item_name,1)
		engfunc( EngFunc_RemoveEntity, iEnt );		
	
	}
	
	

	return FMRES_IGNORED;
}
add_armor(id)
{
	g_roundlimit++
	g_maplimit++
	g_item_used[id]++
	set_pev(id, pev_armorvalue,(float(g_max_value)))
	emit_sound(id, CHAN_BODY, szSound, 1.0, ATTN_NORM, 0, PITCH_HIGH)
	if (g_pcvar_icon )	UTIL_Send_PickupMessage( id, szIcon );	
	/*if (g_pcvar_hud)
	{	
		new amount = min(g_pcvar_item_maplimit - g_maplimit, min(g_pcvar_item_roundlimit_global - g_roundlimit ,g_pcvar_item_roundlimit_player - g_item_used[id]))
		UTIL_Send_PickupHud (id)
	}	*/
	return
}
remove_armor(id)
{
	set_pev(id, pev_armorvalue,0.0)
	return

}
remove_allentity()
{
	new ent = -1;
	while((ent = fm_find_ent_by_class(ent, gEntClassname)))
		fm_remove_entity(ent);
	return	
}

/***********************************************************
INTERNAL FUNCTIONS (messages,save,load)
**********************************************************/
UTIL_Send_PickupHud (id)
{

	set_hudmessage( 0, 255, 0, gHudxPos,gHudyPos, 2, 2.0, 1.0 );
	show_hudmessage( id, "%s %i",g_item_name,g_item[id]);	
}

stock UTIL_Send_PickupMessage( const id, const szItemName[ ] )
{
	message_begin( MSG_ONE_UNRELIABLE, gGMsgItemPickup, _, id );
        write_string( szItemName );
        message_end( );
}
