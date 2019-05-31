/*
TODO
clean code
maplimits replace?


*/

#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <zombie_plague_special>

/*================================================================================
 [Defines]
=================================================================================*/ 

#define DEBUG
//#define is_valid_player(%1) (1 <= %1 <= 32) 
//#define is_valid_alive_player ((1 <= %1 <= g_maxplayers) && is_user_connected(%1) && is_user_alive(%1))
//#pragma dynamic 32768  
new const PLUGIN[] = "[ZP][ITEM]Armor";
new const VERSION[] = "1.0";
new const AUTHOR[] = "Furion";

#define is_valid_player(%1) (1 <= %1 <= g_maxplayers && is_user_connected(%1)) 
#define is_valid_real_player(%1) (1 <= %1 <= g_maxplayers && is_user_connected(%1) && !is_user_bot(%1) && !is_user_hltv(%1)) 

/*================================================================================
 [Tasks]
=================================================================================*/ 
/*================================================================================
 [global vars]
=================================================================================*/
// Class ID
new g_item_id;
new const g_item_name[] = "Armor";
new g_maxplayers;
new bool: g_roundlive = false
new bool:g_lastzombie[33];
new bool:g_lasthuman[33];
new bool:g_firstzombie[33];

new gGMsgItemPickup;
//new gGMsgStatusIcon;

//new const g_item_useteam[] = "Human" //same with register extra item!! its for use picked  entity
//new const g_item_freeteam[] = "Classic"			//real names need from zpsp_zombieclasses not use Zombie here:D
new const g_item_dropteam[] = "Classic Zombie,Raptor Zombie,Big Zombie,Poison Zombie,Leech Zombie"
new const g_item_pickupteam[] = "Team Zombie,Team Human"
new const g_item_useteam[] = "Team Human"

new const gEntClassname[ ] = "armor_entity";
//precaches
new const szModelKit[ ] = "models/w_kevlar.mdl";
new const szPickupSound[ ] = "zombie_plague/ammodrop.wav";
new const szSound[] = "items/tr_kevlar.wav";
new const szIcon[] = "suit_full";
//new szSprite[] = "suit_full";
enum _: iCoords
{
	x = 0,
	y,
	z
};

new Float:gHudxPos = 0.07;
new Float:gHudyPos = 0.250;

//define value
const g_max_value = 100;

//cvars
new cvar_item_use,cvar_item_drop
new cvar_item_roundlimit_player,cvar_item_roundlimit_global,cvar_item_maplimit;
new cvar_icon,cvar_hud,cvar_sound;

new	g_pcvar_item_drop,g_pcvar_item_use 
new g_pcvar_item_roundlimit_player,g_pcvar_item_roundlimit_global,g_pcvar_item_maplimit;
new g_pcvar_icon,g_pcvar_hud,g_pcvar_sound;

new g_item[33];
new g_item_used[33];
new bool:g_info[33];


new g_roundlimit;
new g_maplimit;


const MAX_TEMP_SAVE = 64
// Temporary Database vars (used to restore players stats in case they get disconnected)
new g_steamid[33][35] 
new db_steamid[MAX_TEMP_SAVE][35], db_item[MAX_TEMP_SAVE]
new Float:db_time[MAX_TEMP_SAVE]

/*================================================================================
 [Init, CFG and Precache]
=================================================================================*/

public plugin_precache()
{
	//cvar_dropteam = register_cvar("zp_armor_dropteam","Classic Zombie")	;
	//cvar_pickupteam = register_cvar("zp_armor_pickupteam","Zombie|Human")	;
	cvar_item_drop = register_cvar("zp_armor_drop","1"); 
	cvar_item_use = register_cvar("zp_armor_use","1");  //-1 nobuy from menu 0- cant use picked 1 all enable
	cvar_item_roundlimit_player = register_cvar("zp_armor_roundlimit","5")	;
	cvar_item_roundlimit_global = register_cvar("zp_armor_roundlimit_g","20");
	cvar_item_maplimit = register_cvar("zp_armor_maplimit","30");	
	cvar_icon = register_cvar("zp_armor_icon","1")	;
	cvar_hud = register_cvar("zp_armor_hud","1");
	cvar_sound = register_cvar("zp_armor_sound","1")	;
	precache_sound(szSound);
	precache_sound(szPickupSound)	;
	precache_model( szModelKit );
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_clcmd("say /armor", "cmdUse",_,"")  
	register_clcmd("say armor", "cmdUseHelp",_,"") 		
	//get_pcvar_string(cvar_dropteam,g_item_dropteam,charsmax(g_item_dropteam));
	//get_pcvar_string(cvar_pickupteam,g_item_pickupteam,charsmax(g_item_pickupteam));
	g_pcvar_item_drop = get_pcvar_num(cvar_item_drop)		
	g_pcvar_item_use = get_pcvar_num(cvar_item_use)	
	g_pcvar_item_roundlimit_player = get_pcvar_num(cvar_item_roundlimit_player);
	g_pcvar_item_roundlimit_global = get_pcvar_num(cvar_item_roundlimit_global)	;
	g_pcvar_item_maplimit = get_pcvar_num(cvar_item_maplimit)	;
	g_pcvar_icon = get_pcvar_num(cvar_icon)	;
	g_pcvar_hud	 = get_pcvar_num(cvar_hud);
	g_pcvar_sound	 = get_pcvar_num(cvar_sound)	;
	register_event("DeathMsg", "event_death", "a")		;
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0");
	gGMsgItemPickup = get_user_msgid( "ItemPickup" );	
	//gGMsgStatusIcon = get_user_msgid("StatusIcon")
	g_maxplayers = get_maxplayers()	;
	g_item_id = zp_register_extra_item(g_item_name, 20, ZP_TEAM_HUMAN);
	register_forward( FM_Touch, "forward_FM_Touch" );	
}
public plugin_cfg()
{
	g_roundlimit = 0;
	g_maplimit = 0;
}
public OnConfigsExecuted()
{	

}
/***********************************************************
NATIVES
**********************************************************/

public plugin_natives()
{
	register_native("give_item_ex", "native_give_item_ex", 1)			//add 'amount'  item to player
	register_native("remove_item_ex", "native_remove_item_ex", 1)		//remove 'amount' item from player 
	register_native("use_item_ex", "native_use_item_ex", 1)				// force to use jut if he not limited	
	register_native("item_ex_quantity", "native_item_ex_quantity", 1)		//picked quantity	

//	register_native("item_ex_expire", "native_item_ex_expire", 1)			//If have timelimit
//	register_native("item_ex_cooldown", "native_item_ex_cooldown", 1)		//if have cooldown
}
public native_give_item_ex(const id,const item_name[],amount)
{
	if ( !is_valid_player(id) ) return false;
	if (equal(item_name,g_item_name))
	{
		(!amount) ?	(g_item[id]++) : (g_item[id] += amount);
		if(g_info[id] == false){
			client_print_color(id ,print_team_default,  "^4 Felvettél egy %s-t . További információkért írd be chatben a '^1%s^4' szót",g_item_name,g_item_name) ;
			g_info[id] = true;
		}
		if (g_pcvar_hud) UTIL_Send_PickupHud( id );
		if (g_pcvar_icon )	UTIL_Send_PickupMessage( id, szIcon );		
		if(g_pcvar_sound)	UTIL_Send_Sound (id,szPickupSound);	
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
		else (g_item[id] > 0) ? (g_item[id]--) : (g_item[id] = 0);
		return true;
	}
	return false;
}

public native_use_item_ex(id,const item_name[],set)
{
	if (!is_valid_player(id)) 	return false;
	if (equal(item_name,g_item_name) )
	{ 	
		if(set)
		{
			if(!usechecks(id) || g_pcvar_item_use <= 0 ) return false
			add_item(id);
			if(g_pcvar_sound)	UTIL_Send_Sound (id,szSound);

			//if (g_pcvar_icon )	UTIL_StatusIcon(id, szSprite, 1)
			return true;
		}	
		else
		{
			remove_item(id);
			return true;
		}
	}
	return false	;
}

public native_item_ex_quantity(id,item_name[])
{
	if (!is_valid_player(id)) 
		return -1;
	if (equal(item_name,g_item_name))
		return g_item[id];
	else return 0
}


/*================================================================================
 [MAIN ]
=================================================================================*/

public zp_extra_item_selected_pre(id, itemid)
{
	if (itemid == g_item_id)
	{
	
		if(g_pcvar_item_use <= 0)return ZP_PLUGIN_SUPERCEDE;
		if (!usechecks(id)) return ZP_PLUGIN_HANDLED;

	}
	return PLUGIN_CONTINUE;
}

public zp_extra_item_selected(id, itemid)
{
	if(itemid == g_item_id)
	{
	
		if(g_pcvar_item_use <= 0)return ZP_PLUGIN_HANDLED;
		else if (!usechecks(id)) return ZP_PLUGIN_HANDLED;
		else
		{
			native_use_item_ex(id,g_item_name,1);
		}
	}
	return PLUGIN_HANDLED;
}

public usechecks(id)
{
	if (g_roundlive == false) return false;
	if (g_item_used[id]>=g_pcvar_item_roundlimit_player) return false;		
	if (g_roundlimit>=g_pcvar_item_roundlimit_global) return false;		
	if (g_maplimit>=g_pcvar_item_maplimit) return false;		
	if (get_user_armor(id) > 99) return false;
	return true
}

public client_connect(id)
{
	g_item_used[id] = 0;
	g_item[id]= 0;
	g_info[id] = false;
	g_lastzombie[id] = false;
	g_lasthuman[id]= false;
	g_firstzombie[id] = false;
	
} 
public client_putinserver(id)
{
	if (!is_user_bot(id) && !is_user_hltv(id))	get_user_authid(id, g_steamid[id], charsmax(g_steamid[]))
	else get_user_name(id, g_steamid[id], charsmax(g_steamid[]))
	load_stats(id)
}
public zp_user_humanize_post(id)
{

}
public zp_user_infected_post(id)
{

	if (zp_get_user_zombie_class(id) != -1 && zp_get_user_first_zombie(id)) g_firstzombie[id] = true;
	//UTIL_StatusIcon(id,  szSprite, 0)


}


public zp_user_last_zombie(id)
{

	g_lastzombie[id] = true;
}

public zp_user_last_human(id)
{


	g_lasthuman[id] = true;

}
public event_death()
{
	new killer = read_data(1);
	new victim = read_data(2);
	if (!is_valid_player(victim)) return PLUGIN_HANDLED;	
	if (victim == killer) return PLUGIN_HANDLED;
	if (g_pcvar_item_roundlimit_player == 0 ||
		g_pcvar_item_roundlimit_global == 0 ||
		g_pcvar_item_maplimit == 0		) return PLUGIN_HANDLED;
	if (!g_pcvar_item_drop		) return PLUGIN_HANDLED;
	if (!g_item_dropteam[0]) return PLUGIN_HANDLED;
	//UTIL_StatusIcon(victim,  szSprite, 0)	
	new iCast[64];
	if(zp_get_user_zombie(victim))
	{
		if (zp_get_user_zombie_class(victim) == -1) zp_get_special_class_name(victim, iCast, charsmax(iCast)) 	;
		else zp_get_zombie_class_realname (zp_get_user_zombie_class(victim),  iCast, charsmax( iCast))	;
	}
	else
	{
		zp_get_special_class_name(victim, iCast, charsmax(iCast)) ;
	}
#if defined DEBUG	
	log_amx("dropteam: %s cast: %s",g_item_dropteam	, iCast)
#endif
	if (
	(containi(g_item_dropteam	, iCast) > -1)  ||
	((containi(g_item_dropteam,"Last Human") > -1) && (g_lasthuman[victim] == true))||
	((containi(g_item_dropteam,"Last Zombie") > -1) && (g_lastzombie[victim] == true))||
	((containi(g_item_dropteam,"First Zombie") >-1) && (g_firstzombie[victim] == true))||
	((containi(g_item_dropteam,"Team Zombie") >-1) && (zp_get_user_zombie(victim) && zp_get_user_zombie_class(victim) > -1))||	
	((containi(g_item_dropteam,"Team Human") >-1) && (!zp_get_user_zombie(victim) && !zp_get_human_special_class(victim) ))	
	) 
	{
	
		new ran = random_num(0,1);
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
	}
	return PLUGIN_HANDLED;	
}


public client_disconnected(id)
{
	if (!is_user_bot(id)&& !is_user_hltv(id))	get_user_authid(id, g_steamid[id], charsmax(g_steamid[]))
	else get_user_name(id, g_steamid[id], charsmax(g_steamid[]))
	save_stats(id)
	g_item_used[id] = 0;
	g_item[id]= 0;
	g_info[id] = false;
	g_lastzombie[id] = false;
	g_lasthuman[id]= false;
	g_firstzombie[id] = false;
	//UTIL_StatusIcon(id,  szSprite, 0)
}
public event_round_start()
{
	g_roundlimit = 0;
	remove_allentity();
	for (new id; id <= g_maxplayers; id++)
	{
		if (is_user_connected(id))
		{		
			g_item_used[id] = 0;
			g_lastzombie[id] = false;
			g_lasthuman[id]= false;
			g_firstzombie[id] = false;
		}
	}
}

public zp_round_started(gamemode, id)
{
	g_roundlive = true
}

public zp_round_ended(winteam)
{
	g_roundlive = false
}
/***********************************************************
EXTRAITEM  FUNCTIONS (messages,save,load)
**********************************************************/
public forward_FM_Touch( iEnt, id )
{
	if( !pev_valid( iEnt ) || !is_user_alive(id) || is_user_bot(id) ) return FMRES_IGNORED;
	if (!g_item_pickupteam[0]) return FMRES_IGNORED;
	
	new iCast[64];
	if(zp_get_user_zombie(id))
	{
		if (zp_get_user_zombie_class(id) == -1) zp_get_special_class_name(id, iCast, charsmax(iCast)) 	;
		else zp_get_zombie_class_realname (zp_get_user_zombie_class(id),  iCast, charsmax( iCast))	;
	}
	else
	{
		zp_get_special_class_name(id, iCast, charsmax(iCast)) ;
	}

#if defined DEBUG	
	log_amx("touch: %s cast: %s",g_item_pickupteam	, iCast)
#endif	
	if (
	(containi(g_item_pickupteam	, iCast) > -1)  ||
	((containi(g_item_pickupteam,"Last Human") > -1) && (g_lasthuman[id] == true))||
	((containi(g_item_pickupteam,"Last Zombie") > -1) && (g_lastzombie[id] == true))||
	((containi(g_item_pickupteam,"First Zombie") >-1) && (g_firstzombie[id] == true))||
	((containi(g_item_pickupteam,"Team Zombie") >-1) && (zp_get_user_zombie(id) && zp_get_user_zombie_class(id) > -1))||	
	((containi(g_item_pickupteam,"Team Human") >-1) && (!zp_get_user_zombie(id) && !zp_get_human_special_class(id) ))	
	) 
	{	
		new szClassname[ 32 ];
		pev( iEnt, pev_classname, szClassname, charsmax( szClassname ) );
		if( !equal( szClassname, gEntClassname ) )	return FMRES_IGNORED;

		native_give_item_ex(id,g_item_name,1);

		engfunc( EngFunc_RemoveEntity, iEnt );			
	}
	return FMRES_IGNORED;
}
public cmdUse(id)
{
	if (!is_valid_player(id)) return PLUGIN_HANDLED
	if (g_item[id] < 1 ) return PLUGIN_HANDLED	
	if (!usechecks(id)) return PLUGIN_HANDLED	
	if (g_pcvar_item_use < 0) return PLUGIN_HANDLED	
	new iCast[64];
	if(zp_get_user_zombie(id))
	{
		if (zp_get_user_zombie_class(id) == -1) zp_get_special_class_name(id, iCast, charsmax(iCast)) 	;
		else zp_get_zombie_class_realname (zp_get_user_zombie_class(id),  iCast, charsmax( iCast))	;
	}
	else
	{
		zp_get_special_class_name(id, iCast, charsmax(iCast)) ;
	}	
	
#if defined DEBUG	
	log_amx("use: %s cast: %s",g_item_useteam	, iCast)
#endif	
	if (
	(containi(g_item_useteam	, iCast) > -1)  ||
	((containi(g_item_useteam,"Last Human") > -1) && (g_lasthuman[id] == true))||
	((containi(g_item_useteam,"Last Zombie") > -1) && (g_lastzombie[id] == true))||
	((containi(g_item_useteam,"First Zombie") >-1) && (g_firstzombie[id] == true))||
	((containi(g_item_useteam,"Team Zombie") >-1) && (zp_get_user_zombie(id) && zp_get_user_zombie_class(id) > -1))||	
	((containi(g_item_useteam,"Team Human") >-1) && (!zp_get_user_zombie(id) && !zp_get_human_special_class(id) ))	
	)
	{
		native_remove_item_ex(id,g_item_name,1)
		native_use_item_ex(id,g_item_name,1)
	}

	return PLUGIN_HANDLED
}
public cmdUseHelp(id)
{
	if (!is_valid_player(id) ) return PLUGIN_HANDLED
	
	client_print_color(id ,print_team_default,  "^4 Jelenleg ^1'%i'^4 %s képességed van. Használat: '^1/heal^4' a chatben (vagy'^1+heal^4' a konzolban) ",g_item[id],g_item_name)
	client_print_color(id ,print_team_default,  "^4 szabadon kapja: ^1'%s'^4 vásárolhatja:  ^1'Predator'^4 használhatják: ^1%s^4  ","Senki",g_item_useteam)
	client_print_color(id ,print_team_default,  "^4 dobja: ^1%s^4  felveheti: ^1%s^4 ",g_item_dropteam,g_item_pickupteam)
	return PLUGIN_HANDLED




}

add_item(id)
{
	g_roundlimit++;
	g_maplimit++;
	g_item_used[id]++;
	set_pev(id, pev_armorvalue,(float(g_max_value)));
	return;
}
remove_item(id)
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
UTIL_Send_PickupHud(id)
{
	set_hudmessage( 0, 255, 0, gHudxPos,gHudyPos, 2, 2.0, 1.0 );
	show_hudmessage( id, "%s %i",g_item_name,g_item[id]);	
}
UTIL_Send_Sound(const id, const sound[])
{
	emit_sound( id, CHAN_ITEM, sound, VOL_NORM, ATTN_NORM, 0 , PITCH_NORM );
}
stock UTIL_Send_PickupMessage( const id, const szItemName[ ] )
{
	message_begin( MSG_ONE_UNRELIABLE, gGMsgItemPickup, _, id );
        write_string( szItemName );
        message_end( );
}
/*
UTIL_StatusIcon(id, sprname[], run)
{	
	if (!is_valid_real_player(id)) return;

	message_begin(MSG_ONE, gGMsgStatusIcon, {0,0,0}, id);
	write_byte(run); // status (0=hide, 1=show, 2=flash)
	write_string(sprname); // sprite name
	if (run)
	{
		write_byte(255); // red
		write_byte(0); // green
		write_byte(0); // blue		
	}
	message_end();
}*/



load_stats(id)
{
	// Look for a matching record
	static i
	for (i = 0; i < sizeof db_steamid; i++)
	{
		if(equal(g_steamid[id], db_steamid[i]))
		{
			// Bingo! Load
			g_item[id] = db_item[i]

			return;
		}
	}
}


save_stats(id)
{
	// Look for a matching record
	new i
	new	iOldestSlot = -1 
	new Float:iTime = get_gametime()
	
	for (i = 0; i < sizeof db_steamid; i++)
	{	
		if (0 < db_time[i] < iTime)
		{
			iOldestSlot = i	
			iTime = db_time[i]
		}
		// matching record, overwrite
		if(equal(g_steamid[id], db_steamid[i]) )
		{
			copy(db_steamid[i], charsmax(db_steamid[]), g_steamid[id])
			db_item[i] = g_item[id]
			db_time[i] = get_gametime()
			break;
		}
		else
		{
			// slot not empty
			if(db_steamid[i][0] )
			{
				// Last slot, need overwrite oldest slot
				if(i == sizeof db_steamid - 1)
				{
					copy(db_steamid[iOldestSlot], charsmax(db_steamid[]), g_steamid[id])
					db_item[iOldestSlot] = g_item[id]
					db_time[iOldestSlot] = get_gametime()
					break;				
				}
				//go next slot
				else 
				{
						
					continue;
				}
			}
			// Empty slot, write data
			else 
			{	
				copy(db_steamid[i], charsmax(db_steamid[]), g_steamid[id])
				db_item[i] = g_item[id]
				db_time[i] = get_gametime()
				break;
			}				
		}
	}
}	

