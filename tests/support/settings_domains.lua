-- All independent player-facing Pokemon, battle and economy choices. World
-- progression dependencies have their own exhaustive matrix in the audit.
return {
 {'bst_match',{false,true}}, {'bst_difference',{0,50,500}},
 {'base_stats',{'UNCHANGED','SHUFFLE','RANDOM'}}, {'types',{'UNCHANGED','FOLLOW_EVOS','RANDOM'}},
 {'evolutions',{'UNCHANGED','RANDOM'}}, {'impossible_evos',{false,true}},
 {'starters',{'UNCHANGED','RANDOM','TWO_EVOS'}}, {'rival_starter',{false,true}},
 {'movesets',{'UNCHANGED','TYPE_BIAS','RANDOM'}}, {'trainers',{'UNCHANGED','RANDOM','SIMILAR','TYPE_THEMED'}},
 {'wild_randomness',{'BALANCED','UNRESTRICTED'}}, {'wild_evolution',{'AS_ROLLED','LEVEL'}},
 {'area_encounters',{'VANILLA','HIGH_VARIETY','AREA_POOL','CHAOS_POOL','FULL_SLOT_RANDOM'}},
 {'extra_species',{0,1,2,3,4,5}}, {'statics',{'UNCHANGED','RANDOM','SIMILAR'}},
 {'tms',{'UNCHANGED','RANDOM'}}, {'tm_compat',{'UNCHANGED','TYPE_BIAS','RANDOM','FULL'}},
 {'pc_item',{false,true}}, {'marts',{'VANILLA','SAFE','CHAOS'}}, {'mart_safety',{false,true}},
 {'trades',{'UNCHANGED','GIVEN','BOTH'}}, {'allow_legendaries',{false,true}},
 {'trainer_levels',{-50,-40,-30,-20,-10,0,10,20,30,40,50}},
 {'boss_levels',{-50,-40,-30,-20,-10,0,10,20,30,40,50}},
 {'wild_levels',{-50,-40,-30,-20,-10,0,10,20,30,40,50}},
 {'trainer_ai',{'NORMAL','STRONG'}}, {'boss_ai',{'NORMAL','STRONG'}},
 {'seed_mode',{'AUTO','MANUAL'}}, {'manual_seed',{1,2147483646}},
}
