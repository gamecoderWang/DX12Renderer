cbuffer CameraData : register(b0)
{
    float4x4 globalView;
    float4x4 globalProj;
    float4x4 globalViewProj;                                //�����������ӽ��µ�
    float4x4 globalViewProjForShadow;           //�����������Ӱ��ͼ����pass�еľ��������viewproj�ǹ�Դ�ӽ��µ�
    float4x4 globalProjTex;
    float4x4 globalInverseProj;
    float4x4 globalShadowMVP;
    float4 globalEyePostion;
};