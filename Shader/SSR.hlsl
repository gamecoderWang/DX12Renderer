#include "CommonFunction.hlsl"

struct Light
{
    float3 lightColor;
    float fallOffStart;
    float4 direction;
    float4 position;
};

static const float4 globalSampleVec[54] =
{
    float4(+1.0f, +1.0f, +1.0f, 0.0f),
	float4(-1.0f, -1.0f, -1.0f, 0.0f),

	float4(-1.0f, +1.0f, +1.0f, 0.0f),
	float4(+1.0f, -1.0f, -1.0f, 0.0f),

	float4(+1.0f, +1.0f, -1.0f, 0.0f),
	float4(-1.0f, -1.0f, +1.0f, 0.0f),

	float4(-1.0f, +1.0f, -1.0f, 0.0f),
	float4(+1.0f, -1.0f, +1.0f, 0.0f),

	float4(-1.0f, 0.0f, 0.0f, 0.0f),
	float4(+1.0f, 0.0f, 0.0f, 0.0f),

	float4(0.0f, -1.0f, 0.0f, 0.0f),
	float4(0.0f, +1.0f, 0.0f, 0.0f),
	
	float4(0.0f, 0.0f, -1.0f, 0.0f),
	float4(0.0f, 0.0f, +1.0f, 0.0f),
    
    //�ұ����ϵİ˸���
	float4(1.0f, 0.33333f, 0.33333f, 0.0f),
	float4(1.0f, 1.0f, 0.33333f, 0.0f),

	float4(1.0f, 0.33333f, -0.33333f, 0.0f),
	float4(1.0f, 1.0f, -0.333333f, 0.0f),

	float4(1.0f, -0.33333f, 0.33333f, 0.0f),
	float4(1.0f, -1.0f, 0.33333f, 0.0f),

	float4(1.0f, -0.33333f, -0.33333f, 0.0f),
	float4(1.0f, -1.0f, -0.333333f, 0.0f),

	//ǰ��İ˸���
	float4(0.33333f, 0.33333f, 1.0f, 0.0f),
	float4(0.33333f, 1.0f, 1.0f, 0.0f),

	float4(-0.33333f, 0.33333f, 1.0f, 0.0f),
	float4(-0.33333f, 1.0f, 1.0f, 0.0f),

	float4(0.33333f, -0.33333f, 1.0f, 0.0f),
	float4(0.33333f, -1.0f, 1.0f, 0.0f),

	float4(-0.33333f, -0.33333f, 1.0f, 0.0f),
	float4(-0.33333f, -1.0f, 1.0f, 0.0f),

	//������ϵİ˸���
	float4(-1.0f, 0.33333f, 0.33333f, 0.0f),
	float4(1.0f, 1.0f, 0.33333f, 0.0f),

	float4(-1.0f, 0.33333f, -0.33333f, 0.0f),
	float4(-1.0f, 1.0f, -0.333333f, 0.0f),

	float4(-1.0f, -0.33333f, 0.33333f, 0.0f),
	float4(-1.0f, -1.0f, 0.33333f, 0.0f),

	float4(-1.0f, -0.33333f, -0.33333f, 0.0f),
	float4(-1.0f, -1.0f, -0.333333f, 0.0f),

	//����İ˸���
	float4(0.33333f, 0.33333f, -1.0f, 0.0f),
	float4(0.33333f, 1.0f, -1.0f, 0.0f),

	float4(-0.33333f, 0.33333f, -1.0f, 0.0f),
	float4(-0.33333f, 1.0f, -1.0f, 0.0f),

	float4(0.33333f, -0.33333f, -1.0f, 0.0f),
	float4(0.33333f, -1.0f, -1.0f, 0.0f),

	float4(-0.33333f, -0.33333f, -1.0f, 0.0f),
	float4(-0.33333f, -1.0f, -1.0f, 0.0f),

	//������ĸ���
	float4(0.3333f, +1.0f, 0.3333f, 0.0f),
	float4(-0.33333f, 1.0f, 0.33333f, 0.0f),

	float4(0.3333f, +1.0f, -0.3333f, 0.0f),
	float4(-0.33333f, 1.0f, -0.33333f, 0.0f),

	//�����ĸ���
	float4(0.3333f, -1.0f, 0.3333f, 0.0f),
	float4(-0.33333f, -1.0f, 0.33333f, 0.0f),

	float4(0.3333f, -1.0f, -0.3333f, 0.0f),
	float4(-0.33333f, -1.0f, -0.33333f, 0.0f)
};

//SSR������
static const int globalSSRSampleCount = 20;

Texture2D globalGBufferDiffuse : register(t0, space0);
Texture2D globalGBufferNormal : register(t1, space0);       //����ռ��µķ���
Texture2D globalGBufferDepth : register(t2, space0);
Texture2D globalGBufferDirectLight : register(t3, space0);
Texture2D globalShadowMap : register(t4, space0);
Texture2D globalSSAORandomVecMap : register(t5, space0);

SamplerState globalSampler : register(s0);
SamplerComparisonState globalComSampler : register(s1);
SamplerState globalsamPointClamp : register(s2);
SamplerState globalsamDepthMap : register(s3);

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
	bool globalOpenIndirectLight;
};


float2 GetScreenCoord(float4 worldPos)
{
    float4 projPos = mul(worldPos, globalViewProj);
    projPos /= projPos.w;
    projPos = TextureTranform(projPos);
    return projPos.xy;
}

float GetDepthFromWorldPosition(float4 worldPos)
{
    float4 projPos = mul(worldPos, globalViewProj);
    projPos /= projPos.w;
    return projPos.z;
}

//TODO:����UI��Ӳ�������ֶ���Ҫ�ĳɱ�����̬�޸�
bool RayMarch(float3 ori, float3 dir, out float3 hitPos)
{
    float step = 50.0f;
    float3 currentPoint = ori;
    
    for (int i = 0; i < 20; ++i)
    {
        float3 testPoint = currentPoint + step * dir;
        
        float testDepth = GetDepthFromWorldPosition(float4(testPoint, 1.0f));       //����ĩ�˵�����
        float bufferDepth = globalGBufferDepth.Sample(globalsamDepthMap, GetScreenCoord(float4(testPoint, 1.0f)));  //��ǰ������С���
        
        //����1����С��0��ʾ�����Ѿ�������׶�壬û�н���
		if (bufferDepth > 0.999999f || bufferDepth < 0.0000001f)
			return false;
        
		float deltaDepth = testDepth - bufferDepth;
        
        //������֮��С��0���ߴ���0.1����ʾû�к������ཻ
        if(deltaDepth < 0.0f || deltaDepth >0.1f)
        {
            currentPoint = testPoint;
            continue;
        }
        else if(deltaDepth > 0.002)     //С��0.1����0.002��ʾ�ཻ�ˣ�������Сһ��������̽
        {
            step /= 2.0f;
        }
        else        //С��0.002��ʾ����ĩ�˵���Ǻ�����Ľ��㡣
        {
            hitPos = testPoint;
            return true;
        }
    }
    return false;
}

struct VertexInput
{
    float3 pos : POSITION;
    float2 uv : TEXCOORD;
    float3 normal : NORMAL;
};

struct VertexOuput
{
    float4 pos : SV_Position;
    float4 posW : POSITIONT0;
    float2 uv : TEXCOORD;
};

VertexOuput VSMain(VertexInput vin)
{
    VertexOuput output;
    output.posW = mul(float4(vin.pos, 1.0f), globalWorldMatrix);
    output.pos = mul(output.posW, globalViewProj);
    output.uv = vin.uv;
    return output;
}

float4 PSMain(VertexOuput pin) : SV_Target
{
    float3 indirectLight = { 0.0f, 0.0f, 0.0f };
    float3 directLight = { 0.0f, 0.0f, 0.0f };
    
    float2 uv = GetScreenCoord(pin.posW);
    float3 worldNormal = globalGBufferNormal.Sample(globalsamPointClamp, uv).xyz;
    float4 diffuseAlbedo = globalGBufferDiffuse.Sample(globalsamPointClamp, uv);
    directLight = globalGBufferDirectLight.Sample(globalsamPointClamp, uv).xyz;
    
	if (globalOpenIndirectLight == false)
		return float4(directLight, diffuseAlbedo.a);
    
	float3 randVec = 2.0f * globalSSAORandomVecMap.Sample(globalSampler, GetScreenCoord(pin.posW)).xyz - 1.0f;
    
    for (int i = 0; i < globalSSRSampleCount; ++i)  
    {
        float3 offset = normalize(reflect(globalSampleVec[i].xyz, randVec));
        float flipValue = sign(dot(worldNormal, offset));
        offset *= flipValue;
        
        float3 hitPos;
        if (RayMarch(pin.posW.xyz, offset, hitPos))
        {
            float2 uv = GetScreenCoord(float4(hitPos, 1.0f));
            float3 lightColor = globalGBufferDirectLight.Sample(globalsamPointClamp, uv).xyz;
            float m = globalShininess * 256.0f;
            float3 lightDir = normalize(pin.posW.xyz - hitPos);
            float3 tempDirectLight = ComputeDirectionalLight(lightDir, lightColor, pin.posW.xyz, worldNormal, m, diffuseAlbedo, globalFresnelR0);
            float distance = length(pin.posW.xyz - hitPos);
            float weight = 1.0f - distance / 1000.0f;
            indirectLight += tempDirectLight * weight;
        }
    }
    //indirectLight = pow(indirectLight, 2.0f);
   
    indirectLight /= 2.0f;
    
    return float4(directLight + indirectLight, diffuseAlbedo.a);
}