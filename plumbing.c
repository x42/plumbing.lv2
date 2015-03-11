#include "route.c"
#include "midieat.c"

const void*
extension_data(const char* uri)
{
	return NULL;
}


#define M_DESCRIPTOR(ID) \
static const LV2_Descriptor descriptor_ ## ID = { \
	PLB_URI # ID,                             \
	m_instantiate,                            \
	m_connect_port,                           \
	NULL,                                     \
	m_run,                                    \
	NULL,                                     \
	m_cleanup,                                \
	extension_data                            \
};


#define A_DESCRIPTOR(ID) \
static const LV2_Descriptor descriptor_ ## ID = { \
	PLB_URI # ID,                             \
	a_instantiate,                            \
	a_connect_port,                           \
	NULL,                                     \
	a_run,                                    \
	NULL,                                     \
	a_cleanup,                                \
	extension_data                            \
};

M_DESCRIPTOR(eat1)
M_DESCRIPTOR(eat2)
M_DESCRIPTOR(gen1)
M_DESCRIPTOR(gen2)

A_DESCRIPTOR(route_1_2)
A_DESCRIPTOR(route_1_3)

A_DESCRIPTOR(route_2_1)
A_DESCRIPTOR(route_2_2)
A_DESCRIPTOR(route_2_3)

A_DESCRIPTOR(route_3_1)
A_DESCRIPTOR(route_3_2)
A_DESCRIPTOR(route_3_3)

#undef LV2_SYMBOL_EXPORT
#ifdef _WIN32
#    define LV2_SYMBOL_EXPORT __declspec(dllexport)
#else
#    define LV2_SYMBOL_EXPORT  __attribute__ ((visibility ("default")))
#endif
LV2_SYMBOL_EXPORT
const LV2_Descriptor*
lv2_descriptor(uint32_t index)
{
	switch (index) {
		case  0: return &descriptor_eat1;
		case  1: return &descriptor_eat2;
		case  2: return &descriptor_gen1;
		case  3: return &descriptor_gen2;

		case  4: return &descriptor_route_1_2;
		case  5: return &descriptor_route_1_3;

		case  6: return &descriptor_route_2_1;
		case  7: return &descriptor_route_2_2;
		case  8: return &descriptor_route_2_3;

		case  9: return &descriptor_route_3_1;
		case 10: return &descriptor_route_3_2;
		case 11: return &descriptor_route_3_3;
		default: return NULL;
	}
}
