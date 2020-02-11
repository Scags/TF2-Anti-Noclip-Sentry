#include <sdktools>
#include <dhooks>

public Plugin myinfo = 
{
	name = "TF2 Sentry Fix", 
	author = "Scag", 
	description = "Patches exploit concerning the \"noclip sentry\"", 
	version = "1.0.0", 
	url = ""
};

#define SCALE 0.1	// The higher, the closer the bullets start to the center of the sentry

public void OnPluginStart()
{
	GameData conf = LoadGameConfigFile("tf2.sentryfix");
	Handle hook = DHookCreateDetourEx(conf, "CObjectSentrygun::Fire", CallConv_THISCALL, ReturnType_Bool, ThisPointer_CBaseEntity);
	if (!hook)
		SetFailState("Could not load detour for CObjectSentrygun::Fire!");
	DHookEnableDetour(hook, false, CObjectSentrygun_Fire);
	DHookEnableDetour(hook, true, CObjectSentrygun_Fire_Post);

	hook = DHookCreateDetourEx(conf, "CBaseAnimating::GetAttachment", CallConv_THISCALL, ReturnType_Bool, ThisPointer_CBaseEntity);
	if (!hook)
		SetFailState("Could not load detour for CBaseAnimating::GetAttachment!");

	DHookAddParam(hook, HookParamType_Int);
	DHookAddParam(hook, HookParamType_ObjectPtr, _, DHookPass_ByRef|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP);	// vecSrc
	DHookAddParam(hook, HookParamType_ObjectPtr, _, DHookPass_ByRef|DHookPass_ODTOR|DHookPass_OCTOR|DHookPass_OASSIGNOP);	// vecAng

	// pThis is -1 in the post hook, o_0
	DHookEnableDetour(hook, false, CBaseAnimating_GetAttachment);
	DHookEnableDetour(hook, true, CBaseAnimating_GetAttachment_Post);

	delete conf;
}

bool yea;
public MRESReturn CObjectSentrygun_Fire(int pThis)
{
	if (GetEntProp(pThis, Prop_Send, "m_iUpgradeLevel") >= 2 && GetEntProp(pThis, Prop_Send, "m_bPlayerControlled"))
		yea = true;
}

public MRESReturn CObjectSentrygun_Fire_Post()
{
	yea = false;
}

int attachignore;
float mypos[3];
public MRESReturn CBaseAnimating_GetAttachment(int pThis, Handle hReturn, Handle hParams)
{
	if (!yea)
		return;

	attachignore = GetEntData(pThis, FindSendPropInfo("CObjectSentrygun", "m_nShieldLevel")+20);
	GetEntPropVector(pThis, Prop_Send, "m_vecOrigin", mypos);
}

public MRESReturn CBaseAnimating_GetAttachment_Post(int pThis, Handle hReturn, Handle hParams)
{
	if (!yea)
		return MRES_Ignored;

	int attachment = DHookGetParam(hParams, 1);
	// Rocket attachment
	if (attachment == attachignore)
		return MRES_Ignored;

	float vecSrc[3];
	DHookGetParamObjectPtrVarVector(hParams, 2, 0, ObjectValueType_Vector, vecSrc);
	float pos[3]; pos = mypos;

//	PrintToChatAll("vecSrc {%.1f, %.1f, %.1f}", vecSrc[0], vecSrc[1], vecSrc[2]);
//	PrintToChatAll("pos {%.1f, %.1f, %.1f}", pos[0], pos[1], pos[2]);

	float finalpos[3]; finalpos = vecSrc;
	pos[2] = vecSrc[2] = 0.0;	// Don't care about z

	float offset[3]; MakeVectorFromPoints(pos, vecSrc, offset);
//	PrintToChatAll("offset {%.1f, %.1f, %.1f}", offset[0], offset[1], offset[2]);
	ScaleVector(offset, SCALE);	// Close enough

//	PrintToChatAll("offsetscaled {%.1f, %.1f, %.1f}", offset[0], offset[1], offset[2]);

	SubtractVectors(vecSrc, offset, vecSrc);

	finalpos[0] = vecSrc[0];
	finalpos[1] = vecSrc[1];

//	PrintToChatAll("finalpos {%.1f, %.1f, %.1f}", finalpos[0], finalpos[1], finalpos[2]);
	DHookSetParamObjectPtrVarVector(hParams, 2, 0, ObjectValueType_Vector, finalpos);
	return MRES_ChangedHandled;
}


/*public void OnEntityCreated(int ent, const char[] classname)
{
	if (!strcmp(classname, "obj_sentrygun", false))
	{
		float v[3];
		GetEntPropVector(ent, Prop_Send, "m_vecBuildMins", v);
		ScaleVector(v, 1.1);
		SetEntPropVector(ent, Prop_Send, "m_vecBuildMins", v);

		GetEntPropVector(ent, Prop_Send, "m_vecBuildMaxs", v);
		ScaleVector(v, 1.1);
		SetEntPropVector(ent, Prop_Send, "m_vecBuildMaxs", v);
	}
}*/

stock Handle DHookCreateDetourEx(GameData conf, const char[] name, CallingConvention callConv, ReturnType returntype, ThisPointerType thisType)
{
	Handle h = DHookCreateDetour(Address_Null, callConv, returntype, thisType);
	if (h)
		DHookSetFromConf(h, conf, SDKConf_Signature, name);
	return h;
}