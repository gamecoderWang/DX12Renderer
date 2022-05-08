#include "CommonData.hlsl"

struct Light
{
    float3 lightColor;
    float fallOffStart;
    float4 direction;
    float3 position;
    float fallOffEnd;
};

Texture2D globalDiffuseTexture : register(t0, space0);
Texture2D globalNormalTexture : register(t1, space0);
Texture2D globalShadowMap : register(t2, space0);

SamplerState globalSampler : register(s0);
SamplerComparisonState globalComSampler : register(s1);

cbuffer MaterialData : register(b1)
{
    float4x4 globalWorldMatrix;
    float4x4 globalNormalWorldMatrix;
    float4 globalDiffuse;
    float4 globalAmbient;
    float4 globalSpecular;
    float3 globalFresnelR0;
    float globalShininess;
    Light globalDirectionalLight;
};

float3 ComputeDirectLight(float3 lightColor, float3 lightDir, float3 normal)
{
    return lightColor * max(0, dot(lightDir, normal)); //������������ʲ����Ҷ���õ���ֱ�����
}

float3 ComputeDiffuse(float3 lightColor, float3 lightDir, float3 normal, float4 diffuseAbedo)
{
    return ComputeDirectLight(lightColor, lightDir, normal) * diffuseAbedo.rgb; //ֱ��������������䷴���ʵõ����������
}

float3 ComputeSpecular(float3 lightColor, float3 lightDir, float3 posW, float3 normal, float m)
{
    float3 viewDir = normalize(posW - globalEyePostion.xyz);

    float3 fresnelRF = globalFresnelR0 + (1 - globalFresnelR0) * pow(1 - saturate(dot(lightDir, normal)), 5); //������ϵ��

    float3 halfDir = normalize(lightDir + viewDir); //ֱ�����۾����ǲ��ֹ��ߺ�����֮���΢ƽ�淨��
    float roughnessFactor = (m + 8) * pow(max(dot(normal, halfDir), 0), m) / 8; //�ֲڶ�ϵ��

    float3 specAbedo = fresnelRF * roughnessFactor;
    specAbedo = specAbedo / (specAbedo + 1.0f); //��Щ�߹����ӻ����1�����û���������Ļ���Щ���ػ���ִ���ɫ
    return ComputeDirectLight(lightColor, lightDir, normal) * specAbedo; //ֱ��������Է�����ϵ�����Դֲڶȵõ��߹����
}

float3 ComputeDirectionalLight(float3 lightDirection, float3 posW, float3 normal, float m, float4 diffuseAbedo)
{
    float3 diffuse = ComputeDiffuse(globalDirectionalLight.lightColor, lightDirection, normal, diffuseAbedo);
    float3 specular = ComputeSpecular(globalDirectionalLight.lightColor, lightDirection, posW, normal, m);
    return diffuse + specular;
}

float CalculateShadowFactor(float4 shadowPosH)
{
    if (shadowPosH.z < 0.0f)
        return 0.0f;
    shadowPosH /= shadowPosH.w;
    float depth = shadowPosH.z;

    //TODO:ȷ������Ӱͼ��С��������һ���ֶ������ڳ�ʼ����һ��Ȼ����
    uint width, height, numLevels;
    globalShadowMap.GetDimensions(0, width, height, numLevels);

    float dx = 1.0f / (float) width;
    float dy = 1.0f / (float) height;

    float2 offset[25] =
    {
        float2(-dx * 2, -dy * 2), float2(-dx, -dy * 2), float2(0, -dy * 2), float2(dx, -dy * 2), float2(dx * 2, -dy * 2),
        float2(-dx * 2, -dy), float2(-dx, -dy), float2(0, -dy), float2(dx, -dy), float2(dx * 2, -dy),
        float2(-dx * 2, 0), float2(-dx, 0), float2(0, 0), float2(dx, 0), float2(dx * 2, 0),
        float2(-dx * 2, dy), float2(-dx, dy), float2(0, dy), float2(dx, dy), float2(dx * 2, dy),
        float2(-dx * 2, dy * 2), float2(-dx, dy * 2), float2(0, dy * 2), float2(dx, dy * 2), float2(dx * 2, dy * 2),
    };

    float persentage = 0;

    [unroll]
    for (int i = 0; i < 25; ++i)
    {
        persentage += globalShadowMap.SampleCmpLevelZero(globalComSampler, shadowPosH.xy + offset[i], depth + 0.005).r;
    }

    return persentage / 25.0f;
}

struct VertexInput
{
    float3 pos : POSITION;
    float2 uv : TEXCOORD;
    float3 normal : NORMAL;
    float3 tangent : TANGENT;
};

struct VertexOutput
{
    float4 posH : SV_POSITION;
    float3 normal_W : NORMAL;
    float2 uv : TEXCOORD;
    float3 worldTangent : TANGENT;
    float4 posW : POSITIONT0;
    float4 shadowPosH : POSITION1;
};

struct PixelOutput
{
    float4 PixelNormal : SV_Target0;        //������ռ���
    float4 PixelDiffuse : SV_Target1;
    float4 PixelWorldNormal : SV_Target2;   //����ռ���
    float4 PixelDirectLight : SV_Target3;
};

VertexOutput VSMain(VertexInput input)
{
    VertexOutput output;
    
    output.posW = mul(float4(input.pos, 1.0f), globalWorldMatrix);

    output.posH = mul(output.posW, globalViewProj);

    output.normal_W = mul(input.normal, (float3x3)globalNormalWorldMatrix);

    output.uv = input.uv;
    
    output.worldTangent = mul(input.tangent, (float3x3) globalWorldMatrix);
    
    output.shadowPosH = mul(output.posW, globalShadowMVP);
    
    return output;
    
}

PixelOutput PSMain(VertexOutput input)
{
    //��������ͼƫ�ƺ�ķ���ֵ������ռ���
    input.normal_W = normalize(input.normal_W);
    input.worldTangent = normalize(input.worldTangent);
    float3 worldBinormal = cross(input.normal_W, input.worldTangent);
    float3x3 worldTBN = float3x3(input.worldTangent, worldBinormal, input.normal_W);
    float4 tempNormal = globalNormalTexture.Sample(globalSampler, input.uv);
    tempNormal = 2.0f * tempNormal - 1.0f;
    float3 worldNormal = mul(tempNormal.rgb, worldTBN);
    
    //����ֱ�ӹ���
    float4 diffuseAlbedo = globalDiffuseTexture.Sample(globalSampler, input.uv);
    float m = globalShininess * 256 * tempNormal.a;
    float3 lightDir = normalize(globalDirectionalLight.position - input.posW.xyz);
    float3 directLight = ComputeDirectionalLight(lightDir, input.posW.xyz, worldNormal, m, diffuseAlbedo);
    float shadowFactor = CalculateShadowFactor(input.shadowPosH);
    directLight *= shadowFactor;
    float3 ambient = { 0.1f, 0.1f, 0.1f };

    //������ռ��·���ֵ
    float4 resNormal;
    resNormal.xyz = mul(input.normal_W, (float3x3)globalView);
    
    PixelOutput output;
    output.PixelNormal = resNormal;
    output.PixelDiffuse = diffuseAlbedo;
    output.PixelWorldNormal = float4(worldNormal, 1.0f);
    output.PixelDirectLight = float4(directLight, 1.0f);
    
    return output;
}