#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_SCREEN

#pragma multi_compile _ _ADDITIONAL_LIGHTS
#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

#ifndef CUSTOM_LIGHTING_FUNCTIONS
#define CUSTOM_LIGHTING_FUNCTIONS

#ifndef SHADERGRAPH_PREVIEW
struct SurfaceVariables
{
    float3 normal;
    float3 view;
    float3 surfaceColor;
    float specularIntensity;
    float shininess;
    float metallic;
};

float CalculateDiffuseLighting(Light light, float3 normal, float minimumDiffuseLighting)
{
    float diffuse = saturate(dot(normal, light.direction));
    float attenuation = light.distanceAttenuation * light.shadowAttenuation;
    
    diffuse *= attenuation;
    diffuse = clamp(diffuse, minimumDiffuseLighting, 1.0);
    
    return diffuse;
}

float CalculateSpecularLighting(Light light, float3 normal, float3 viewDirection, float specularIntensity, float shininess, bool diffuse)
{
    float3 halfVector = SafeNormalize(light.direction + viewDirection);
    float specular = saturate(dot(normal, halfVector));
    
    specular = pow(specular, shininess) * specularIntensity;
    specular *= diffuse;
    
    return specular;
}

float3 CalculateCustomLightingColor(Light light, SurfaceVariables s, float minimumDiffuseLighting)
{
    float diffuse = CalculateDiffuseLighting(light, s.normal, minimumDiffuseLighting);
    
    float realDiffuse = CalculateDiffuseLighting(light, s.normal, 0);
    float specular = CalculateSpecularLighting(light, s.normal, s.view, s.specularIntensity, s.shininess, realDiffuse);
    
    float3 diffuseColor = diffuse * light.color * s.surfaceColor;
    float3 specularColor = lerp(float3(1,1,1), s.surfaceColor, s.metallic) * specular * light.color;
    
    float3 completeColor = diffuseColor + specularColor;
    
    return completeColor;
}
#endif

void GetCustomLightingColor_float(
    float3 Position,
    float3 Normal,
    float3 ViewDirection,
    float3 SurfaceColor,
    float SpecularIntensity,
    float Shininess,
    float Metallic,
    float MinimumDiffuseMainLighting,
    out float3 Color
)
{
#if defined(SHADERGRAPH_PREVIEW)
    Color = float3(1.0, 1.0, 1.0);
#else
    SurfaceVariables s;
    s.normal = Normal;
    s.view = ViewDirection;
    s.surfaceColor = SurfaceColor;
    s.specularIntensity = SpecularIntensity;
    s.shininess = Shininess;
    s.metallic = Metallic;
    
    Color = float3(0.0, 0.0, 0.0);
    
    #if defined(_USEMAINLIGHT)
        #if defined(_USEMAINLIGHTSHADOWS)
            #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
            float4 shadowCoord = ComputeScreenPos(TransformWorldToHClip(Position));
            #else 
            float4 shadowCoord = TransformWorldToShadowCoord(Position);
            #endif
            
            Light mainLight = GetMainLight(shadowCoord);
        #else
            Light mainLight = GetMainLight();
        #endif
        
        Color += CalculateCustomLightingColor(mainLight, s, MinimumDiffuseMainLighting);
        
#endif
    
#if defined(_USEADDITIONALLIGHTS) && defined(_ADDITIONAL_LIGHTS)

        int pixelLightCount = GetAdditionalLightsCount();

        for (int i = 0; i < pixelLightCount; i++)
        {
            Light additionalLight;

            #if defined(_USEADDITIONALLIGHTSSHADOWS) && defined(_ADDITIONAL_LIGHT_SHADOWS)
                additionalLight = GetAdditionalLight(i, Position, 1);
            #else
                additionalLight = GetAdditionalLight(i, Position);
            #endif

            Color += CalculateCustomLightingColor(additionalLight, s, 0); 
        }

#endif

    #endif
}
#endif